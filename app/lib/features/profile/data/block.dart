class Block {
  const Block({required this.id, required this.name, this.number});

  factory Block.fromJson(Map<String, dynamic> json) {
    final number = json['number'] as int?;
    return Block(
        id: json['id'] as String,
        number: number,
        name: json['name'] as String? ?? '$number');
  }

  final String id;
  final String name;
  final int? number;
}
