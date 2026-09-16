import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';

class ChatDirectPickerState {
  const ChatDirectPickerState({
    this.departments = const [],
    this.contacts = const [],
    this.selectedDepartment,
    this.searchQuery = '',
    this.loading = false,
    this.error,
  });
  final List<ChatDepartment> departments;
  final List<ChatUser> contacts;
  final String? selectedDepartment, error;
  final String searchQuery;
  final bool loading;
}

class ChatDirectPickerCubit extends Cubit<ChatDirectPickerState> {
  ChatDirectPickerCubit(this.repository) : super(const ChatDirectPickerState());
  final RichChatRepository repository;
  List<ChatUser>? _cachedAllContacts;

  Future<void> loadDepartments() async {
    emit(
      ChatDirectPickerState(
        departments: state.departments,
        contacts: state.contacts,
        selectedDepartment: null,
        searchQuery: '',
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

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      emit(
        ChatDirectPickerState(
          departments: state.departments,
          contacts: const [],
          selectedDepartment: state.selectedDepartment,
          searchQuery: '',
          loading: false,
        ),
      );
      return;
    }

    emit(
      ChatDirectPickerState(
        departments: state.departments,
        contacts: state.contacts,
        selectedDepartment: state.selectedDepartment,
        searchQuery: trimmed,
        loading: _cachedAllContacts == null,
      ),
    );

    try {
      if (_cachedAllContacts == null) {
        final page = await repository.eligibleContacts();
        _cachedAllContacts = page.items;
      }
      final q = trimmed.toLowerCase();
      final filtered = _cachedAllContacts!
          .where(
            (u) =>
                u.name.toLowerCase().contains(q) ||
                u.department.toLowerCase().contains(q) ||
                u.id.toLowerCase().contains(q),
          )
          .toList();

      if (!isClosed && state.searchQuery == trimmed) {
        emit(
          ChatDirectPickerState(
            departments: state.departments,
            contacts: filtered,
            selectedDepartment: state.selectedDepartment,
            searchQuery: trimmed,
            loading: false,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          ChatDirectPickerState(
            departments: state.departments,
            selectedDepartment: state.selectedDepartment,
            searchQuery: trimmed,
            error: e.toString(),
          ),
        );
      }
    }
  }

  Future<void> chooseDepartment(String id) async {
    emit(
      ChatDirectPickerState(
        departments: state.departments,
        selectedDepartment: id,
        searchQuery: '',
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
            searchQuery: '',
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          ChatDirectPickerState(
            departments: state.departments,
            selectedDepartment: id,
            searchQuery: '',
            error: e.toString(),
          ),
        );
      }
    }
  }
}
