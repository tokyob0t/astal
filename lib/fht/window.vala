namespace AstalFht {
    public class Window: Object {
        public signal void removed();
        public signal void moved_to(Workspace workspace);

        public int id { get; private set; }
        public string title { get; private set; }
        public string app_id { get; private set; }
        public int x { get; private set; }
        public int y { get; private set; }
        public int width { get; private set; }
        public int height { get; private set; }
        public bool focused { get; private set; }
        public bool floating { get; private set; }
        public bool activated { get; private set; }
        public bool maximized { get; private set; }
        public bool fullscreen { get; private set; }
        public Workspace workspace { get; private set; }

        internal void sync(Json.Object obj) {
            var fht = Fht.get_default();

            id = (int)obj.get_int_member("id");
            floating = !obj.get_boolean_member("tiled");
            title = obj.get_string_member("title");
            app_id = obj.get_string_member("app-id");
            x = (int)obj.get_array_member("location").get_int_element(0);
            y = (int)obj.get_array_member("location").get_int_element(1);
            width = (int)obj.get_array_member("size").get_int_element(0);
            height = (int)obj.get_array_member("size").get_int_element(1);
            workspace = fht.get_workspace((int)obj.get_int_member("workspace-id"));
        }

        public void kill(bool force = false) {
            Fht.get_default().action("close-window", @"--window-id=$id --kill=$force");
        }

        public void focus() {
            Fht.get_default().action("focus-window", @"--window-id=$id");
        }

        public void move_to(Workspace ws) {
            var Id = ws.id;
            Fht.get_default().action("send-window-to-workspace", @"--window-id=$id --workspace-id=$Id");
        }

        public void toggle_floating() {
            Fht.get_default().action("float-window", @"--window-id=$id");
        }
    }
}
