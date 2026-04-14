namespace AstalFht {
    public class Output: Object {
        public signal void removed ();

        public string id { get; private set; }
        public string name { get; private set; }
        public string make { get; private set; }
        public string model { get; private set; }
        public string serial { get; private set; }
        public int x { get; private set; }
        public int y { get; private set; }
        public int width { get; private set; }
        public int height { get; private set; }
        public double scale { get; private set; }
        public Transform transform { get; private set; }
        public Array<Mode> modes { get; private set; }
        public Mode active_mode { get; private set; }
        public bool focused { get; private set; }

        internal void sync(Json.Object obj) {
            id = obj.get_string_member("name");
            name  = obj.get_string_member("name");
            make  = obj.get_string_member("make");
            model = obj.get_string_member("model");
            serial = obj.get_string_member("serial");
            scale = obj.get_double_member("scale");
            x = (int)obj.get_array_member("position").get_int_element(0);
            y = (int)obj.get_array_member("position").get_int_element(1);
            width  = (int)obj.get_array_member("size").get_int_element(0);
            height = (int)obj.get_array_member("size").get_int_element(1);

            transform = Transform.from_string(
                obj.get_string_member("transform")
            );

            modes = new Array<Mode>();

            foreach (var m in obj.get_array_member("modes").get_elements())
                modes.append_val(new Mode(m.get_object()));

            active_mode = modes.index((int)obj.get_int_member("active-mode-idx"));
        }

        public void focus() {
            Fht.get_default().action("focus-output", name);
        }

        public class Mode : Object {
            public int width       { get; private set; }
            public int height      { get; private set; }
            public double refresh  { get; private set; }
            public bool preferred  { get; private set; }

            internal Mode(Json.Object obj) {
                width =  (int)obj.get_array_member("dimensions").get_int_element(0);
                height = (int)obj.get_array_member("dimensions").get_int_element(1);
                refresh   = obj.get_double_member("refresh");
                preferred = obj.get_boolean_member("preferred");
            }
        }

        public enum Transform {
            NORMAL,
            ROTATE_90,
            ROTATE_180,
            ROTATE_270,
            FLIPPED,
            FLIPPED_90,
            FLIPPED_180,
            FLIPPED_270;

            public static Transform from_string(string t) {
                switch (t) {
                    case "normal":      return NORMAL;
                    case "90":          return ROTATE_90;
                    case "180":         return ROTATE_180;
                    case "270":         return ROTATE_270;
                    case "flipped":     return FLIPPED;
                    case "flipped-90":  return FLIPPED_90;
                    case "flipped-180": return FLIPPED_180;
                    case "flipped-270": return FLIPPED_270;
                    default:            return NORMAL;
                }
            }
        }
    }
}
