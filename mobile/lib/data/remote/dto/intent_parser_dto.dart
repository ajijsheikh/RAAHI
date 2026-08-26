import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'intent_parser_dto.g.dart';

@JsonSerializable()
class IntentParserDto {
  final String origin;
  final String destination;
  final int maxBudgetInr;
  final DateTime? targetEta;
  final String? emergencyContact;
  final List<String>? amenitiesRequested;

  IntentParserDto({
    required this.origin,
    required this.destination,
    required this.maxBudgetInr,
    this.targetEta,
    this.emergencyContact,
    this.amenitiesRequested,
  });

  factory IntentParserDto.fromJson(Map<String, dynamic> json) =>
      _$IntentParserDtoFromJson(json);

  Map<String, dynamic> toJson() => _$IntentParserDtoToJson(this);
}