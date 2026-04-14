namespace AstalFht {
    public class Workspace : Object {
        public signal void removed();

        private List<weak Window> _windows = new List<weak Window>();

        public int id { get; private set; }
        public bool has_fullscreen { get; private set; }
        public uint8 nmaster { get; private set; }
        public double mwfact { get; private set; }
        public Output output { get; private set; }
        public List<weak Window> windows { owned get { return _windows.copy(); } }

        internal void sync(Json.Object obj) {
            var fht = Fht.get_default();

            id = (int)obj.get_int_member("id");
            has_fullscreen = obj.get_int_member_with_default("fullscreen-window-idx", -1) > 0;
            output = fht.get_output(obj.get_string_member("output"));
            nmaster = (uint8)obj.get_int_member("nmaster");
            mwfact = (double)obj.get_double_member("mwfact");

            var list = new List<weak Window>();

            foreach (var elem in obj.get_array_member("windows").get_elements())
                list.append(fht.get_window((int)elem.get_int()));

            _windows = list.copy();
            notify_property("windows");
        }

        public void focus() {
            Fht.get_default().action("focus-workspace", id.to_string());
        }
    }
}
