namespace AstalFht {
    public Fht get_default() {
        return Fht.get_default();
    }

    public class Fht : Object {
        private static string? SOCKET_PATH = GLib.Environment.get_variable("FHTC_SOCKET_PATH");
        //private static string SOCKET_PATH = "/tmp/debug.sock";

        private static Fht _instance;

        public static Fht? get_default() {
            if (_instance != null)
                return _instance;

            if (GLib.Environment.get_variable("FHTC_SOCKET_PATH") == null) {
                critical("Fht is not running");
                return null;
            }

            var i = new Fht();
            _instance = i;

            try {
                i.socket = i.new_socket();
                i.socket.output_stream.write("\"subscribe\"\n".data, null);
                i.watch_socket(new DataInputStream(i.socket.input_stream));
            } catch (Error err) {
                critical("could not subscribe: %s", err.message);
                return null;
            }

            try {
                i.init();
            } catch (Error err) {
                critical("could not initialize: %s", err.message);
                return null;
            }

            return _instance;
        }

        // outputs, workspaces, clients
        private HashTable<string, Output> _outputs =
            new HashTable<string, Output>(str_hash, str_equal);

        private HashTable<int, Workspace> _workspaces =
            new HashTable<int, Workspace>((i) => i, (a, b) => a == b);

        private HashTable<int, Window> _windows =
            new HashTable<int, Window>((i) => i, (a, b) => a == b);

        public List<weak Output> outputs { owned get { return _outputs.get_values(); } }
        public List<weak Workspace> workspaces { owned get { return _workspaces.get_values(); } }
        public List<weak Window> windows { owned get { return _windows.get_values(); } }

        public Output get_output(string name) { return _outputs.get(name); }
        public Workspace? get_workspace(int id) { return _workspaces.get(id); }
        public Window? get_window(int id) { return  _windows.get(id); }

        public Output focused_output { get; private set; }
        public Workspace focused_workspace { get; private set; }
        public Window focused_window { get; private set; }

        public Position cursor_position {
            owned get {
                return new Position.cursor_pos(_message("cursor-position"));
            }
        }

        // signals
        public signal void event (string event, string args);

        public signal void floating (Window client, bool floating);
        public signal void window_moved (Window window, Workspace ws);

        // state
        public signal void window_added (Window window);
        public signal void window_removed (int id);
        public signal void output_added (Output output);
        public signal void output_removed (string id);

        private SocketConnection socket;

        private SocketConnection? new_socket() {
            try {
                return new SocketClient().connect(new UnixSocketAddress(SOCKET_PATH), null);
            } catch (Error err) {
                critical(err.message);
                return null;
            }
        }

        private void watch_socket(DataInputStream stream) {
            stream.read_line_async.begin(Priority.DEFAULT, null, (_, res) => {
                try {
                    var line = stream.read_line_async.end(res);
                    handle_event.begin(line, (_, res) => {
                        try {
                            handle_event.end(res);
                        } catch (Error err) {
                            critical(err.message);
                        }
                    });
                    watch_socket(stream);
                } catch (Error err) {
                    critical(err.message);
                }
            });
        }

        private void write_socket(
            string message,
            out SocketConnection socket,
            out DataInputStream stream
        ) throws Error {
            socket = new_socket();

            if (socket != null) {
                socket.output_stream.write(message.data, null);
                stream = new DataInputStream(socket.input_stream);
            } else {
                stream = null;
                critical("could not write to the fht-compositor socket");
            }
        }

        public string message(string message, string? args = null) {
            SocketConnection? conn;
            DataInputStream? stream;
            try {
                var msg = message;

                if (args != null && args != "")
                    msg += " " + args;

                if (!(msg.has_prefix("{") && msg.has_suffix("}"))) 
                    msg = "\"" + msg + "\"";

                write_socket(@"$msg\n", out conn, out stream);

                if (stream != null && conn != null) {
                    var res = stream.read_upto("\n", -1, null, null);
                    conn.close(null);
                    return res;
                }
            } catch (Error err) {
                critical(err.message);
            }

            return "";
        }

        internal Json.Object? _message(string message, string? args = null) throws Error {
            var obj = Json.from_string(this.message(message, args)).get_object();

            foreach (var key in obj.get_members()) {
                return obj.get_object_member(key); 
            }

            critical(obj.get_string_member("error"));
            return null;
        }

        public async string message_async(string message, string? args = null) {
            SocketConnection? conn;
            DataInputStream? stream;
            try {

                var msg = message;

                if (args != null && args != "")
                    msg += " " + args;

                if (!(msg.has_prefix("{") && msg.has_suffix("}"))) 
                    msg = "\"" + msg + "\"";

                write_socket(@"$msg\n", out conn, out stream);

                if (stream != null && conn != null) {
                    var res = yield stream.read_upto_async("\n", -1, Priority.DEFAULT, null, null);
                    conn.close(null);
                    return res;
                }
            } catch (Error err) {
                critical(err.message);
            }
            return "";
        }

        public void action(string action, string? args) {
            message_async.begin(action, args, (_, res) => {
                var line = message_async.end(res);

                try {
                    critical("action error: %s", Json.from_string(line).get_object().get_string_member("error"));
                } catch (Error err) {}
            });
        }


        private void init() throws Error {
            var space = _message("space"); // {"monitors":{"eDP-1":{"output":"eDP-1","workspaces":[0,1,2,3,4,5,6,7,8],"active-workspace-idx":1,"active":true}},"primary-idx":0,"active-idx":0}
            var outs = _message("outputs");
            var wnds = _message("windows");

            var mons = space.get_object_member("monitors");

            // create outputs and workspaces
            foreach (var output in mons.get_members()) {
                _outputs.insert(output, new Output());

                var wsIds = mons.get_object_member(output).get_array_member("workspaces");

                foreach (var elem in wsIds.get_elements()) {
                    _workspaces.insert((int)elem.get_int(), new Workspace());
                }
            }

            // create windows 
            foreach (var id in wnds.get_members()) {
                _windows.insert(int.parse(id), new Window());
            }

            // sync outputs  
            foreach (var output in mons.get_members()) {
                get_output(output).sync(outs.get_object_member(output));

                if (mons.get_object_member(output).get_boolean_member("active"))
                    focused_output = get_output(output);

                // sync workspaces 
                var wsIds = mons.get_object_member(output).get_array_member("workspaces");

                foreach (var elem in wsIds.get_elements()) {
                    var wsId = (int)elem.get_int();
                    get_workspace(wsId).sync(_message(@"{\"workspace\":$wsId}"));
                }
            }

            // sync windows 
            foreach (var id in wnds.get_members()) {
                var winId = int.parse(id);
                get_window(winId).sync(wnds.get_object_member(id));
            }

            focused_workspace = get_workspace((int)_message("focused-workspace").get_int_member("id"));
            focused_window = get_window((int)_message("focused-window").get_int_member("id"));
        }

        ~Fht() {
            if (socket != null) {
                try {
                    socket.close(null);
                } catch (Error err) {
                    critical(err.message);
                }
            }
        }

        private void sync_window(Json.Object obj) {
            var id = (int)obj.get_int_member("id");
            var w = get_window(id);

            if (w == null) {
                w = new Window();
                _windows.insert(id, w);
                notify_property("windows");
                window_added(w);
            }

            w.sync(obj);
        }

        private void sync_workspace(Json.Object obj) {
            var id = (int)obj.get_int_member("id");
            var w = get_workspace(id);

            if (w == null) {
                w = new Workspace();
                _workspaces.insert(id, w);
            }

            w.sync(obj);
        }

         private async void handle_event(string line) throws Error {
            var obj = Json.from_string(line).get_object();

            var str_event = obj.get_string_member("event");

            if (str_event == "layer-shells") // ToDo
                return;

            var data = obj.get_object_member("data");

            switch (str_event) {
                case "space": {
                    var monitors = data.get_object_member("monitors");

                    foreach (var key in monitors.get_members()) {
                        var monitor = monitors.get_object_member(key);

                        if (monitor.get_boolean_member("active")) {
                            focused_output = get_output(monitor.get_string_member("output"));
                            break;  
                        }
                    }

                    break;
                }
                //case "layer-shells": { break; }
                case "workspaces": {
                    foreach (var id in data.get_members()) {
                        sync_workspace(data.get_object_member(id));
                    }

                    notify_property("workspaces");
                    break;
                }
                case "windows": {
                    foreach (var id in data.get_members()) {
                        sync_window(data.get_object_member(id));
                    }

                    notify_property("windows");
                    break;
                }
                case "workspace-changed": {
                    sync_workspace(data);

                    var node = data.get_member("active-window-idx");

                    if (node != null && node.get_node_type() != Json.NodeType.NULL) {
                       int focusedWinIdx = (int)data.get_int_member("active-window-idx");

                       focused_window = get_window(
                           (int)data.get_array_member("windows").get_int_element(focusedWinIdx)
                       );
                    }

                    break;
                }
                case "window-changed": {
                    sync_window(data);

                    break;
                }
                case "window-closed": {
                    var id = (int)data.get_int_member("id");
                    _windows.get(id).removed();
                    _windows.remove(id);
                    window_removed(id);
                    notify_property("windows");
                    break;
                }
                case "focused-window-changed": {
                    focused_window = get_window((int)data.get_int_member("id"));
                    break;
                }
                case "active-workspace-changed": {
                    focused_workspace = get_workspace((int)data.get_int_member("id"));
                    break;
                }
                default: {
                    warning("Unhandled event: %s", str_event);
                    break;
                }
            }

            var node = new Json.Node(Json.NodeType.OBJECT);
            node.set_object(data);

            event(str_event, Json.to_string(node, false));
        }
    }
}
