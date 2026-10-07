import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/custom_request_template.dart';
import '../domain/repositories/custom_request_template_repository.dart';

class CustomRequestTemplateRepositoryImpl implements CustomRequestTemplateRepository {
  CustomRequestTemplateRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<CustomRequestType>> loadRequestTypes() async {
    final snap = await _firestore.collection('customRequestTypes').get();
    return snap.docs
        .map((doc) => CustomRequestType.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<void> saveRequestType(CustomRequestType requestType) async {
    final ref = requestType.id.isEmpty
        ? _firestore.collection('customRequestTypes').doc()
        : _firestore.collection('customRequestTypes').doc(requestType.id);

    final toSave = CustomRequestType(
      id: ref.id,
      nameAr: requestType.nameAr,
      category: requestType.category,
      descriptionAr: requestType.descriptionAr,
      isActive: requestType.isActive,
      subtypes: requestType.subtypes,
      fields: requestType.fields,
      approvalSteps: requestType.approvalSteps,
      updatedAt: DateTime.now(),
    );

    await ref.set(toSave.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteRequestType(String id) async {
    await _firestore.collection('customRequestTypes').doc(id).delete();
  }
}
