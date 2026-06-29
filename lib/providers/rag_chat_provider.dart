import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import '../features/ai/chat/chat_message_store.dart';
import '../models/resident.dart';
import '../models/handover_note.dart';
import '../services/resident_service.dart';
import '../services/handover_service.dart';
import 'ai_provider.dart';

/// Retrieval-augmented chat: fetches care records for the active home and
/// injects them as context before every LLM call. The context is rebuilt
/// once per home and cached; call [refresh] or [loadContext] on home-switch.
///
/// Chat messages displayed in the UI always show the user's original text —
/// the augmented prompt (with care records prepended) is sent to the model
/// but never exposed to the UI.
class RagChatProvider extends ChangeNotifier {
  RagChatProvider(this._ai) {
    _ai.addListener(notifyListeners);
  }

  final AiProvider _ai;

  @override
  void dispose() {
    _ai.removeListener(notifyListeners);
    super.dispose();
  }
  final _residentService = ResidentService();
  final _handoverService = HandoverService();

  String _contextBlock = '';
  bool _indexing = false;
  String? _indexError;
  int? _indexedHomeId;
  int _residentCount = 0;
  int _handoverCount = 0;

  // ── Delegates ──────────────────────────────────────────────────────────────
  ModelState get state => _ai.state;
  List<ChatMsg> get messages => _ai.messages;
  bool get generating => _ai.generating;

  // ── Context loading state ──────────────────────────────────────────────────
  bool get indexing => _indexing;
  String? get indexError => _indexError;
  bool get hasContext => _contextBlock.isNotEmpty;
  int get residentCount => _residentCount;
  int get handoverCount => _handoverCount;

  /// Load (or refresh) the care record context for [homeId].
  /// Skips the network fetch if context is already loaded for the same home.
  Future<void> loadContext(int homeId, {bool force = false}) async {
    if (!force && _indexedHomeId == homeId && _contextBlock.isNotEmpty) return;
    _indexing = true;
    _indexError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _residentService.list(homeId: homeId),
        _handoverService.list(limit: 14),
        ChatMessageStore.instance.load(homeId),
      ]);
      final residents = results[0] as List<Resident>;
      final allHandovers = results[1] as List<HandoverNote>;
      final history = results[2] as List<ChatMsg>;

      // Filter handovers to this home (API may not filter server-side).
      final handovers = allHandovers
          .where((h) => h.homeId == null || h.homeId == homeId)
          .toList();

      _contextBlock = _build(residents, handovers);
      _indexedHomeId = homeId;
      _residentCount = residents.length;
      _handoverCount = handovers.length;
      _ai.setMessages(history);
      dev.log(
        'RAG context built: ${residents.length} residents, '
        '${handovers.length} handovers, ${history.length} history msgs',
        name: 'RagChat',
      );
    } catch (e, st) {
      dev.log('loadContext failed', name: 'RagChat', error: e, stackTrace: st);
      _indexError = 'Could not load care records: $e';
      _contextBlock = '';
    } finally {
      _indexing = false;
      notifyListeners();
    }
  }

  /// Wipe cached context — call when the active home changes.
  void clearContext() {
    _contextBlock = '';
    _indexedHomeId = null;
    _residentCount = 0;
    _handoverCount = 0;
    notifyListeners();
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  Future<void> send(String userMessage) async {
    final prompt = _contextBlock.isNotEmpty
        ? 'I have read the following care home records:\n\n'
            '${_contextBlock.trim()}\n\n'
            'Based on those records, $userMessage'
        : userMessage;
    final prevCount = _ai.messages.length;
    await _ai.send(userMessage, promptText: prompt);
    // Persist the new user + AI messages that were just added.
    if (_indexedHomeId != null) {
      final msgs = _ai.messages;
      for (int i = prevCount; i < msgs.length; i++) {
        if (msgs[i].text.isNotEmpty) {
          await ChatMessageStore.instance.append(_indexedHomeId!, msgs[i]);
        }
      }
    }
  }

  Future<void> stopGeneration() => _ai.stopGeneration();

  Future<void> clearChat() async {
    if (_indexedHomeId != null) {
      await ChatMessageStore.instance.clear(_indexedHomeId!);
    }
    await _ai.clearChat();
  }

  // ── Context builder ────────────────────────────────────────────────────────

  String _build(List<Resident> residents, List<HandoverNote> handovers) {
    final sb = StringBuffer();
    sb.writeln('Care home resident records and recent handover notes:');
    sb.writeln();

    if (residents.isNotEmpty) {
      sb.writeln('RESIDENTS:');
      for (final r in residents) {
        sb.write('• ${r.firstName} ${r.lastName}');
        if (r.roomNumber != null) sb.write(' — Room ${r.roomNumber}');
        sb.write(' | Care level: ${r.careLevel}');
        sb.write(' | Fall risk: ${r.fallRisk}');
        sb.write(' | Mobility: ${r.mobility}');
        if (r.dnacpr) sb.write(' | DNACPR');
        if (r.conditions.isNotEmpty) {
          sb.write(' | Conditions: ${r.conditions.join(', ')}');
        }
        if (r.medications.isNotEmpty) {
          sb.write(' | Medications: ${r.medications.join(', ')}');
        }
        if (r.allergies.isNotEmpty) {
          sb.write(' | Allergies: ${r.allergies.join(', ')}');
        }
        if (r.nextOfKin != null) sb.write(' | NOK: ${r.nextOfKin}');
        sb.writeln();
      }
    }

    if (handovers.isNotEmpty) {
      sb.writeln();
      sb.writeln('RECENT HANDOVER NOTES (newest first):');
      for (final h in handovers) {
        sb.writeln('• ${h.createdLabel} [${h.shiftLabel}]: ${h.content}');
      }
    }

    return sb.toString();
  }
}
