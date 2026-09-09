import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';

class ChatDirectPickerState {
  const ChatDirectPickerState({
    this.departments = const [],
    this.contacts = const [],
    this.selectedDepartment,
    this.loading = false,
    this.error,
  });
  final List<ChatDepartment> departments;
  final List<ChatUser> contacts;
  final String? selectedDepartment, error;
  final bool loading;
}

class ChatDirectPickerCubit extends Cubit<ChatDirectPickerState> {
  ChatDirectPickerCubit(this.repository) : super(const ChatDirectPickerState());
  final RichChatRepository repository;
  Future<void> loadDepartments() async {
    emit(
      ChatDirectPickerState(
        departments: state.departments,
        contacts: state.contacts,
        selectedDepartment: state.selectedDepartment,
        loading: true,
      ),
    );
    try {
      final page = await repository.contactDepartments();
      if (!isClosed) {
        emit(ChatDirectPickerState(departments: page.items));
      }
    } catch (e) {
      if (!isClosed) {
        emit(ChatDirectPickerState(error: e.toString()));
      }
    }
  }

  Future<void> chooseDepartment(String id) async {
    emit(
      ChatDirectPickerState(
        departments: state.departments,
        selectedDepartment: id,
        loading: true,
      ),
    );
    try {
      final page = await repository.eligibleContacts(department: id);
      if (!isClosed) {
        emit(
          ChatDirectPickerState(
            departments: state.departments,
            contacts: page.items,
            selectedDepartment: id,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          ChatDirectPickerState(
            departments: state.departments,
            selectedDepartment: id,
            error: e.toString(),
          ),
        );
      }
    }
  }
}
