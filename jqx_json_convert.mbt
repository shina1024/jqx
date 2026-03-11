///|
/// Convert a standard MoonBit `Json` value into jqx's internal core `Value`.
fn to_core_value(input : Json) -> @core.Value {
  match input {
    Null => @core.Value::null()
    True => @core.Value::boolean(true)
    False => @core.Value::boolean(false)
    Number(n, repr~) => @core.Value::number(n, repr?)
    String(s) => @core.Value::string(s)
    Array(values) => @core.Value::array(values.map(to_core_value))
    Object(obj) => {
      let entries = []
      for kv in obj.to_array() {
        entries.push((kv.0, to_core_value(kv.1)))
      }
      @core.Value::object_from_entries(entries)
    }
  }
}

///|
/// Convert jqx's internal core `Value` into standard MoonBit `Json`.
fn from_core_value(input : @core.Value) -> Json {
  match input {
    @core.JNull => null
    @core.JTrue => Json::boolean(true)
    @core.JFalse => Json::boolean(false)
    @core.Number(n, repr) => Json::number(n, repr?)
    @core.String(s) => Json::string(s)
    @core.Array(values) => Json::array(values.map(from_core_value))
    @core.Object(obj) => {
      let out = Map::new()
      for kv in obj.iter() {
        out[kv.0] = from_core_value(kv.1)
      }
      Json::object(out)
    }
  }
}
