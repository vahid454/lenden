import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/payment_promise_entity.dart';

class PaymentPromiseModel extends PaymentPromiseEntity {
  const PaymentPromiseModel({
    required super.id,
    required super.userId,
    required super.customerId,
    required super.amount,
    super.fulfilledAmount,
    required super.promisedDate,
    super.status,
    super.note,
    super.lastContactedAt,
    super.followUpNote,
    required super.createdAt,
    required super.updatedAt,
  });

  factory PaymentPromiseModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final now = DateTime.now();
    return PaymentPromiseModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      fulfilledAmount: (data['fulfilledAmount'] as num?)?.toDouble() ?? 0,
      promisedDate: (data['promisedDate'] as Timestamp?)?.toDate() ?? now,
      status: PaymentPromiseStatusX.fromString(data['status'] as String? ?? ''),
      note: data['note'] as String?,
      lastContactedAt: (data['lastContactedAt'] as Timestamp?)?.toDate(),
      followUpNote: data['followUpNote'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? now,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? now,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'customerId': customerId,
        'amount': amount,
        'fulfilledAmount': fulfilledAmount,
        'promisedDate': Timestamp.fromDate(promisedDate),
        'status': status.firestoreValue,
        if (note != null && note!.isNotEmpty) 'note': note,
        if (lastContactedAt != null)
          'lastContactedAt': Timestamp.fromDate(lastContactedAt!),
        if (followUpNote != null && followUpNote!.isNotEmpty)
          'followUpNote': followUpNote,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory PaymentPromiseModel.fromEntity(PaymentPromiseEntity entity) =>
      PaymentPromiseModel(
        id: entity.id,
        userId: entity.userId,
        customerId: entity.customerId,
        amount: entity.amount,
        fulfilledAmount: entity.fulfilledAmount,
        promisedDate: entity.promisedDate,
        status: entity.status,
        note: entity.note,
        lastContactedAt: entity.lastContactedAt,
        followUpNote: entity.followUpNote,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}
