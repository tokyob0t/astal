namespace AstalFht {

    public class Position : Object {
        public int x { get; construct set; }
        public int y  { get; construct set; }

        internal Position.cursor_pos(Json.Object obj) {
            try {
                x = (int)obj.get_double_member("x");
                y = (int)obj.get_double_member("y");
            } catch {
                x = 0;
                y = 0;
            }
        }
    }
}
