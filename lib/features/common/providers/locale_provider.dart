import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers.dart';

// Use Notifier (Riverpod 2.0) instead of StateNotifier
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    // Listen for auth changes to load language preference
    ref.listen(authStateProvider, (previous, next) {
      final user = next.value?.session?.user;
      if (user != null) {
        final savedLang = user.userMetadata?['language_code'];
        if (savedLang != null && savedLang is String) {
          // Avoid unnecessary rebuilds
          if (state.languageCode != savedLang) {
            state = Locale(savedLang);
          }
        }
      }
    });
    return const Locale('en');
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    _startSave(locale);
  }

  void toggle() {
    Locale nextLocale;
    if (state.languageCode == 'en') {
      nextLocale = const Locale('ru');
    } else if (state.languageCode == 'ru') {
      nextLocale = const Locale('zh');
    } else {
      nextLocale = const Locale('en');
    }
    state = nextLocale;
    _startSave(nextLocale);
  }

  Future<void> _startSave(Locale locale) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'language_code': locale.languageCode}),
        );
      } catch (e) {
        debugPrint('Failed to save language: $e');
      }
    }
  }
}

// Simple Dictionary for MVP
final translationsProvider = Provider<Map<String, Map<String, String>>>((ref) {
  return {
    'en': {
      'app_title': 'RiffLocker',
      'my_songs': 'My Songs',
      'tune_guitar': 'Tune Guitar',
      'search_songs': 'Search Songs',
      'account': 'Account',
      'change_password': 'Change Password',
      'logout': 'Sign Out',
      'sign_in': 'Sign In',
      'sign_up': 'Sign Up',
      'email': 'Email',
      'password': 'Password',
      'language': 'Language',
      'add_song': 'Add New Song',
      'edit_song': 'Edit Song',
      'save': 'Save',
      'title': 'Title',
      'artist': 'Artist',
      'key': 'Key',
      'content': 'Content',
      'strumming': 'Strumming Pattern',
      'empty_library': 'Your Library is Empty',
      'start_adding': 'Start by adding a song!',
      'clone_success': 'Song added to your library!',
      'welcome_back': 'Welcome Back',
      'create_account': 'Create Account',
      'guest_continue': 'Continue as Guest',
      'editor_title': 'Song Editor',
      'lyrics_chords': 'Lyrics & Chords (ChordPro format)',
      'pick_audio': 'Pick Audio File',
      'audio_selected': 'Audio Selected',
      'enter_title': 'Enter song title',
      'enter_artist': 'Enter artist name',
      'enter_key': 'Enter key (e.g., C, Am)',
      'strumming_hint': 'e.g. D-DU-UD-',
      'lyrics_hint':
          'Enter lyrics here...\nUse brackets for chords: "Hello [Am]world"',
      'new_password': 'New Password',
      'confirm_password': 'Confirm Password',
      'change_password_success': 'Password changed successfully!',
      'password_mismatch': 'Passwords do not match',
      'enter_current_password': 'Enter current password',
      'current_password': 'Current Password',
      'incorrect_password': 'Incorrect current password',
      'delete_song_title': 'Delete Song?',
      'delete_song_message':
          'Are you sure? If you are the author, it will be deleted for everyone. If you cloned it, it will be removed only from your library.',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'deleting': 'Deleting...',
      'back_tooltip': 'Back',
      'menu_tooltip': 'Open navigation menu',
      'delete_song_tooltip': 'Delete Song',
      'add_to_library_tooltip': 'Add to My Songs',
      'required_field': 'Required',
      'password_min_length': 'Min 6 chars',
      'edit_song_tooltip': 'Edit Song',
    },
    'ru': {
      'app_title': 'RiffLocker',
      'my_songs': 'Мои Песни',
      'tune_guitar': 'Настроить Гитару',
      'search_songs': 'Поиск Песен',
      'account': 'Аккаунт',
      'change_password': 'Сменить Пароль',
      'logout': 'Выйти',
      'sign_in': 'Войти',
      'sign_up': 'Регистрация',
      'email': 'Почта',
      'password': 'Пароль',
      'language': 'Язык',
      'add_song': 'Новая песня',
      'edit_song': 'Редактировать',
      'save': 'Сохранить',
      'title': 'Название',
      'artist': 'Исполнитель',
      'key': 'Тональность',
      'content': 'Текст и Аккорды',
      'strumming': 'Бой',
      'empty_library': 'Ваша библиотека пуста',
      'start_adding': 'Добавьте свою первую песню!',
      'clone_success': 'Песня добавлена в вашу библиотеку!',
      'welcome_back': 'С возвращением',
      'create_account': 'Создать Аккаунт',
      'guest_continue': 'Войти как Гость',
      'editor_title': 'Редактор Песни',
      'lyrics_chords': 'Текст и Аккорды',
      'pick_audio': 'Выбрать Аудио',
      'audio_selected': 'Аудио выбрано',
      'enter_title': 'Введите название',
      'enter_artist': 'Введите исполнителя',
      'enter_key': 'Тональность (напр. C, Am)',
      'strumming_hint': 'например D-DU-UD-',
      'lyrics_hint':
          'Введите текст здесь...\nИспользуйте скобки для аккордов: "Привет [Am]мир"',
      'new_password': 'Новый Пароль',
      'confirm_password': 'Подтвердите Пароль',
      'change_password_success': 'Пароль успешно изменен!',
      'password_mismatch': 'Пароли не совпадают',
      'enter_current_password': 'Введите текущий пароль',
      'current_password': 'Текущий Пароль',
      'incorrect_password': 'Неверный текущий пароль',
      'delete_song_title': 'Удалить Песню?',
      'delete_song_message':
          'Вы уверены? Если вы автор, песня удалится у всех. Если вы добавили ее себе, она удалится только у вас.',
      'cancel': 'Отмена',
      'delete': 'Удалить',
      'deleting': 'Удаление...',
      'back_tooltip': 'Назад',
      'menu_tooltip': 'Открыть меню',
      'delete_song_tooltip': 'Удалить Песню',
      'add_to_library_tooltip': 'Добавить в Мои Песни',
      'required_field': 'Обязательно',
      'password_min_length': 'Мин. 6 символов',
      'edit_song_tooltip': 'Редактировать Песню',
    },
    'zh': {
      'app_title': 'RiffLocker',
      'my_songs': '我的歌曲',
      'tune_guitar': '吉他调音',
      'search_songs': '搜索歌曲',
      'account': '账户',
      'change_password': '更改密码',
      'logout': '登出',
      'sign_in': '登录',
      'sign_up': '注册',
      'email': '邮箱',
      'password': '密码',
      'language': '语言',
      'add_song': '添加歌曲',
      'edit_song': '编辑歌曲',
      'save': '保存',
      'title': '标题',
      'artist': '艺术家',
      'key': '调式',
      'content': '歌词和和弦',
      'strumming': '扫弦模式',
      'empty_library': '您的曲库是空的',
      'start_adding': '开始添加歌曲吧！',
      'clone_success': '歌曲已添加到您的曲库！',
      'welcome_back': '欢迎回来',
      'create_account': '创建账户',
      'guest_continue': '以游客身份继续',
      'editor_title': '歌曲编辑器',
      'lyrics_chords': '歌词和和弦',
      'pick_audio': '选择音频文件',
      'audio_selected': '已选择音频',
      'enter_title': '输入歌曲标题',
      'enter_artist': '输入艺术家姓名',
      'enter_key': '输入调式 (例如 C, Am)',
      'new_password': '新密码',
      'confirm_password': '确认密码',
      'change_password_success': '密码修改成功！',
      'password_mismatch': '密码不匹配',
      'enter_current_password': '输入当前密码',
      'current_password': '当前密码',
      'incorrect_password': '当前密码不正确',
      'delete_song_title': '删除歌曲？',
      'delete_song_message': '您确定要删除这首歌曲吗？如果您是原作者，它将对所有人删除。如果您是克隆的，它将仅从您的库中删除。',
      'cancel': '取消',
      'delete': '删除',
      'deleting': '正在删除...',
      'back_tooltip': '返回',
      'menu_tooltip': '打开菜单',
      'delete_song_tooltip': '删除歌曲',
      'add_to_library_tooltip': '添加到我的歌曲',
      'required_field': '必填',
      'password_min_length': '最少6个字符',
      'edit_song_tooltip': '编辑歌曲',
    },
  };
});

// Helper extension to translate strings easily in UI
extension TranslationHelper on BuildContext {
  String tr(String key, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final dict = ref.watch(translationsProvider);
    return dict[locale.languageCode]?[key] ?? key;
  }
}
