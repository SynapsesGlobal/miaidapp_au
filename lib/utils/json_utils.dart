/// JSON 解析相关的通用工具方法。
///
/// 适用于读取生成的 model 未覆盖的字段：直接对原始解析后的 JSON 树
/// （`jsonDecode` 的结果）做查找，兼容字段所处的层级。

/// 在解析后的 JSON 树（Map/List 嵌套）中递归查找指定的布尔字段，找到即返回；
/// 未找到返回 null。
bool? findBoolDeep(dynamic node, String key) {
  if (node is Map) {
    for (final entry in node.entries) {
      if (entry.key == key && entry.value is bool) return entry.value as bool;
      final found = findBoolDeep(entry.value, key);
      if (found != null) return found;
    }
  } else if (node is List) {
    for (final item in node) {
      final found = findBoolDeep(item, key);
      if (found != null) return found;
    }
  }
  return null;
}