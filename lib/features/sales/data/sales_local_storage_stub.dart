class SalesLocalStorage {
  static final Map<String, String> _memory = {};

  String? read(String key) => _memory[key];

  void write(String key, String value) {
    _memory[key] = value;
  }
}
