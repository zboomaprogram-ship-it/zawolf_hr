import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/custom_request_template.dart';
import '../../domain/repositories/custom_request_template_repository.dart';

class RequestChainsSettingsState {
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;
  final List<CustomRequestType> requestTypes;
  final CustomRequestType? selectedType;

  const RequestChainsSettingsState({
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
    this.requestTypes = const [],
    this.selectedType,
  });

  RequestChainsSettingsState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
    List<CustomRequestType>? requestTypes,
    CustomRequestType? selectedType,
    bool clearSelected = false,
  }) => RequestChainsSettingsState(
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    errorMessage: errorMessage,
    successMessage: successMessage,
    requestTypes: requestTypes ?? this.requestTypes,
    selectedType: clearSelected ? null : (selectedType ?? this.selectedType),
  );
}

class RequestChainsSettingsCubit extends Cubit<RequestChainsSettingsState> {
  RequestChainsSettingsCubit({required CustomRequestTemplateRepository repository})
      : _repository = repository,
        super(const RequestChainsSettingsState());

  final CustomRequestTemplateRepository _repository;

  Future<void> loadRequestTypes() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final items = await _repository.loadRequestTypes();
      emit(state.copyWith(isLoading: false, requestTypes: items));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل أنواع الطلبات: $e'));
    }
  }

  void selectType(CustomRequestType? type) {
    emit(state.copyWith(selectedType: type, clearSelected: type == null));
  }

  Future<bool> saveRequestType(CustomRequestType requestType) async {
    emit(state.copyWith(isSaving: true, errorMessage: null, successMessage: null));
    try {
      await _repository.saveRequestType(requestType);
      final items = await _repository.loadRequestTypes();

      emit(state.copyWith(
        isSaving: false,
        requestTypes: items,
        selectedType: requestType,
        successMessage: 'تم حفظ إعدادات الطلب ومسار الاعتماد بنجاح',
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(isSaving: false, errorMessage: 'تعذر حفظ الإعدادات: $e'));
      return false;
    }
  }

  Future<bool> deleteRequestType(String id) async {
    emit(state.copyWith(isSaving: true));
    try {
      await _repository.deleteRequestType(id);
      final updatedList = state.requestTypes.where((x) => x.id != id).toList();
      emit(state.copyWith(
        isSaving: false,
        requestTypes: updatedList,
        clearSelected: state.selectedType?.id == id,
        successMessage: 'تم حذف نوع الطلب بنجاح',
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(isSaving: false, errorMessage: 'تعذر حذف نوع الطلب: $e'));
      return false;
    }
  }
}
