class AttributeFieldModel {
  final String key;
  final String label;
  final String type; // text, number, select
  final String? placeholder;
  final bool required;
  final List<String>? options;

  AttributeFieldModel({
    required this.key,
    required this.label,
    required this.type,
    this.placeholder,
    this.required = false,
    this.options,
  });

  factory AttributeFieldModel.fromJson(Map<String, dynamic> json) {
    return AttributeFieldModel(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      placeholder: json['placeholder']?.toString(),
      required: json['required'] == true,
      options: json['options'] != null
          ? List<String>.from((json['options'] as List).map((e) => e.toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'label': label,
      'type': type,
      'placeholder': placeholder,
      'required': required,
      'options': options,
    };
  }
}
