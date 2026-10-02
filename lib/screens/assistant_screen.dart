// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import '../services/ai_config.dart';
import '../services/assistant_service.dart';

const _kBlue    = Color(0xFF388bfd);
const _kBg      = Color(0xFF0d1117);
const _kSurface = Color(0xFF161b22);
const _kSurface2 = Color(0xFF21262d);
const _kBorder  = Color(0xFF30363d);
const _kMuted   = Color(0xFF8b949e);
const _kRed     = Color(0xFFf85149);

const _suggestions = [
  '¿Cuándo y dónde jugamos?',
  '¿Cómo está la tabla?',
  '¿Quiénes son los goleadores?',
  '¿Cuánto dura cada tiempo?',
  '¿Qué pasa si un equipo llega tarde?',
];

class _ChatMessage {
  final bool fromUser;
  String text;
  bool isError;
  _ChatMessage(this.text, {required this.fromUser, this.isError = false});
}

/// Chat con el asistente. [dataContext] son los datos de la pantalla principal
/// al momento de abrirlo (ver buildAssistantContext).
class AssistantScreen extends StatefulWidget {
  final String dataContext;
  final String categoryLabel;
  const AssistantScreen({super.key, required this.dataContext, required this.categoryLabel});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMessage>[];
  ChatSession? _chat;
  bool _busy = false;
  int _questions = 0;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final question = text.trim();
    if (question.isEmpty || _busy) return;
    if (_questions >= kAssistantMaxQuestions) {
      setState(() => _messages.add(_ChatMessage(
          'Llegaste al máximo de preguntas de esta conversación. Cerrá y abrí el asistente para empezar otra.',
          fromUser: false, isError: true)));
      return;
    }
    _input.clear();
    final answer = _ChatMessage('', fromUser: false);
    setState(() {
      _busy = true;
      _questions++;
      _messages.add(_ChatMessage(question, fromUser: true));
      _messages.add(answer);
    });
    _scrollToEnd();

    try {
      _chat ??= await AssistantService.startChat(widget.dataContext);
      await for (final chunk in _chat!.sendMessageStream(Content.text(question))) {
        final t = chunk.text;
        if (t == null || !mounted) continue;
        setState(() => answer.text += t);
        _scrollToEnd();
      }
      if (answer.text.trim().isEmpty) throw StateError('respuesta vacía');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        answer.text = AssistantService.errorMessage(e);
        answer.isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: _kBlue),
            const SizedBox(width: 8),
            const Text('Asistente', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(widget.categoryLabel, style: const TextStyle(color: _kMuted, fontSize: 12)),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Expanded(child: _messages.isEmpty ? _buildIntro() : _buildMessages()),
                _buildInput(),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Preguntame sobre partidos, resultados, la tabla, el plantel, los goleadores o el reglamento del torneo.',
          style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions.map((s) => ActionChip(
            label: Text(s, style: const TextStyle(color: Colors.white, fontSize: 12)),
            backgroundColor: _kSurface2,
            side: const BorderSide(color: _kBorder),
            onPressed: () => _send(s),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        final waiting = !m.fromUser && m.text.isEmpty;
        return Align(
          alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 560),
            decoration: BoxDecoration(
              color: m.fromUser ? _kBlue.withOpacity(0.18) : _kSurface,
              border: Border.all(color: m.isError ? _kRed.withOpacity(0.5) : _kBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: waiting
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue))
                : SelectableText(
                    m.text,
                    style: TextStyle(
                      color: m.isError ? _kRed : Colors.white,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              enabled: !_busy,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              maxLength: 300,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Escribí tu pregunta…',
                hintStyle: TextStyle(color: _kMuted),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            color: _kBlue,
            onPressed: _busy ? null : () => _send(_input.text),
          ),
        ],
      ),
    );
  }

  // El ícono de reCAPTCHA está oculto (web/index.html); Google pide mostrar
  // este aviso en su lugar.
  Widget _buildFooter() {
    Widget link(String label, String url) => InkWell(
          onTap: () => html.window.open(url, '_blank'),
          child: Text(label,
              style: const TextStyle(color: _kMuted, fontSize: 10, decoration: TextDecoration.underline)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          const Text('Respuestas generadas con IA; pueden tener errores. No escribas datos personales. Protegido por reCAPTCHA de Google:',
              style: TextStyle(color: _kMuted, fontSize: 10)),
          link('Privacidad', 'https://policies.google.com/privacy'),
          const Text('·', style: TextStyle(color: _kMuted, fontSize: 10)),
          link('Condiciones', 'https://policies.google.com/terms'),
        ],
      ),
    );
  }
}
