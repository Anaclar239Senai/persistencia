
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ListaTarefasApp());
}

class ListaTarefasApp extends StatelessWidget {
  const ListaTarefasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Minhas Tarefas',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F5FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7865C7),
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE8E3F3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF7865C7),
              width: 1.5,
            ),
          ),
        ),
      ),
      home: const TelaTarefas(),
    );
  }
}

class Tarefa {
  final String id;
  String titulo;
  bool concluida;

  Tarefa({
    required this.id,
    required this.titulo,
    this.concluida = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'concluida': concluida,
    };
  }

  factory Tarefa.fromJson(Map<String, dynamic> json) {
    return Tarefa(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      concluida: json['concluida'] as bool? ?? false,
    );
  }
}

enum FiltroTarefas {
  todas,
  pendentes,
  concluidas,
}

class TelaTarefas extends StatefulWidget {
  const TelaTarefas({super.key});

  @override
  State<TelaTarefas> createState() => _TelaTarefasState();
}

class _TelaTarefasState extends State<TelaTarefas> {
  static const String chaveArmazenamento = 'lista_de_tarefas';

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Tarefa> _tarefas = [];
  FiltroTarefas _filtroAtual = FiltroTarefas.todas;

  bool _carregando = true;
  bool _salvando = false;

  int get totalTarefas => _tarefas.length;

  int get tarefasConcluidas =>
      _tarefas.where((tarefa) => tarefa.concluida).length;

  int get tarefasPendentes => totalTarefas - tarefasConcluidas;

  double get progresso {
    if (_tarefas.isEmpty) return 0;
    return tarefasConcluidas / totalTarefas;
  }

  List<Tarefa> get tarefasVisiveis {
    switch (_filtroAtual) {
      case FiltroTarefas.todas:
        return _tarefas;
      case FiltroTarefas.pendentes:
        return _tarefas.where((tarefa) => !tarefa.concluida).toList();
      case FiltroTarefas.concluidas:
        return _tarefas.where((tarefa) => tarefa.concluida).toList();
    }
  }

  @override
  void initState() {
    super.initState();
    _carregarTarefas();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _carregarTarefas() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      final String? dados = preferencias.getString(chaveArmazenamento);

      List<Tarefa> tarefasCarregadas = [];

      if (dados != null && dados.isNotEmpty) {
        final List<dynamic> listaJson = jsonDecode(dados) as List<dynamic>;

        tarefasCarregadas = listaJson.map((item) {
          return Tarefa.fromJson(
            Map<String, dynamic>.from(item as Map),
          );
        }).toList();
      }

      if (!mounted) return;

      setState(() {
        _tarefas = tarefasCarregadas;
        _carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        _carregando = false;
      });

      _mostrarMensagem('Não foi possível carregar as tarefas.');
    }
  }

  Future<bool> _salvarTarefas() async {
    if (mounted) {
      setState(() => _salvando = true);
    }

    try {
      final preferencias = await SharedPreferences.getInstance();

      final String dados = jsonEncode(
        _tarefas.map((tarefa) => tarefa.toJson()).toList(),
      );

      final bool salvo = await preferencias.setString(
        chaveArmazenamento,
        dados,
      );

      if (!mounted) return salvo;

      setState(() => _salvando = false);

      if (!salvo) {
        _mostrarMensagem('Não foi possível salvar os dados.');
      }

      return salvo;
    } catch (erro) {
      if (!mounted) return false;

      setState(() => _salvando = false);
      _mostrarMensagem('Erro ao salvar as tarefas.');

      return false;
    }
  }

  Future<void> _adicionarTarefa() async {
    final String titulo = _controller.text.trim();

    if (titulo.isEmpty) {
      _mostrarMensagem('Digite o título da tarefa.');
      _focusNode.requestFocus();
      return;
    }

    final Tarefa novaTarefa = Tarefa(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      titulo: titulo,
    );

    setState(() {
      _tarefas.insert(0, novaTarefa);
      _controller.clear();
      _filtroAtual = FiltroTarefas.todas;
    });

    final bool salvo = await _salvarTarefas();

    if (salvo && mounted) {
      _mostrarMensagem('Tarefa adicionada com sucesso!');
      _focusNode.requestFocus();
    }
  }

  Future<void> _alternarConclusao(Tarefa tarefa) async {
    setState(() {
      tarefa.concluida = !tarefa.concluida;
    });

    await _salvarTarefas();
  }

  Future<void> _excluirTarefa(Tarefa tarefa) async {
    final int indiceOriginal = _tarefas.indexOf(tarefa);

    if (indiceOriginal == -1) return;

    setState(() {
      _tarefas.remove(tarefa);
    });

    final bool salvo = await _salvarTarefas();

    if (!mounted) return;

    if (salvo) {
      _mostrarMensagem(
        'Tarefa excluída.',
        acao: SnackBarAction(
          label: 'DESFAZER',
          onPressed: () async {
            setState(() {
              final int indice = indiceOriginal.clamp(0, _tarefas.length);
              _tarefas.insert(indice, tarefa);
            });

            await _salvarTarefas();
          },
        ),
      );
    }
  }

  Future<void> _limparConcluidas() async {
    if (tarefasConcluidas == 0) {
      _mostrarMensagem('Não há tarefas concluídas para remover.');
      return;
    }

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar tarefas concluídas?'),
        content: const Text(
          'Todas as tarefas concluídas serão removidas permanentemente '
          'da lista salva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      _tarefas.removeWhere((tarefa) => tarefa.concluida);
    });

    await _salvarTarefas();

    if (mounted) {
      _mostrarMensagem('Tarefas concluídas removidas.');
    }
  }

  void _mostrarMensagem(String mensagem, {SnackBarAction? acao}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          behavior: SnackBarBehavior.floating,
          action: acao,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _carregando
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                children: [
                  _construirCabecalho(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        _construirResumo(),
                        const SizedBox(height: 24),
                        _construirCampoNovaTarefa(),
                        const SizedBox(height: 26),
                        _construirFiltros(),
                        const SizedBox(height: 18),
                        _construirTituloLista(),
                        const SizedBox(height: 12),
                        _construirLista(),
                        if (tarefasConcluidas > 0) ...[
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.center,
                            child: TextButton.icon(
                              onPressed: _limparConcluidas,
                              icon: const Icon(Icons.cleaning_services_outlined),
                              label: const Text('Limpar concluídas'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            _salvando
                                ? 'Salvando alterações...'
                                : 'Seus dados ficam salvos neste dispositivo.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF858097),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _construirCabecalho() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF7865C7),
            Color(0xFF9A83DD),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.checklist_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MINHA ROTINA',
                  style: TextStyle(
                    color: Color(0xFFE9E2FF),
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Minhas tarefas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.spa_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirResumo() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEEEAF7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seu progresso',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF302A42),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            totalTarefas == 0
                ? 'Adicione uma tarefa para começar.'
                : '$tarefasConcluidas de $totalTarefas tarefas concluídas',
            style: const TextStyle(
              color: Color(0xFF858097),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 8,
              backgroundColor: const Color(0xFFEDE9F7),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF8A75D2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _construirIndicador(
                  icone: Icons.list_alt_rounded,
                  valor: totalTarefas,
                  legenda: 'Total',
                  cor: const Color(0xFF7865C7),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _construirIndicador(
                  icone: Icons.schedule_rounded,
                  valor: tarefasPendentes,
                  legenda: 'Pendentes',
                  cor: const Color(0xFFE6A23C),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _construirIndicador(
                  icone: Icons.check_circle_outline_rounded,
                  valor: tarefasConcluidas,
                  legenda: 'Concluídas',
                  cor: const Color(0xFF37A889),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirIndicador({
    required IconData icone,
    required int valor,
    required String legenda,
    required Color cor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icone, color: cor, size: 21),
          const SizedBox(height: 7),
          Text(
            '$valor',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            legenda,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF777187),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirCampoNovaTarefa() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Adicionar tarefa',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF302A42),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                maxLength: 120,
                onSubmitted: (_) => _adicionarTarefa(),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: 'O que você precisa fazer?',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                  contentPadding: EdgeInsets.symmetric(vertical: 17),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              width: 56,
              child: FilledButton(
                onPressed: _adicionarTarefa,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Icon(Icons.add_rounded, size: 28),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _construirFiltros() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _construirBotaoFiltro(
          filtro: FiltroTarefas.todas,
          texto: 'Todas',
        ),
        _construirBotaoFiltro(
          filtro: FiltroTarefas.pendentes,
          texto: 'Pendentes',
        ),
        _construirBotaoFiltro(
          filtro: FiltroTarefas.concluidas,
          texto: 'Concluídas',
        ),
      ],
    );
  }

  Widget _construirBotaoFiltro({
    required FiltroTarefas filtro,
    required String texto,
  }) {
    final bool selecionado = _filtroAtual == filtro;

    return ChoiceChip(
      label: Text(texto),
      selected: selecionado,
      showCheckmark: false,
      onSelected: (_) {
        setState(() {
          _filtroAtual = filtro;
        });
      },
      selectedColor: const Color(0xFFE6DFFF),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selecionado
            ? const Color(0xFFB4A2EB)
            : const Color(0xFFE8E3F3),
      ),
      labelStyle: TextStyle(
        color: selecionado
            ? const Color(0xFF6550B0)
            : const Color(0xFF777187),
        fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Widget _construirTituloLista() {
    String titulo;

    switch (_filtroAtual) {
      case FiltroTarefas.todas:
        titulo = 'Sua lista';
        break;
      case FiltroTarefas.pendentes:
        titulo = 'Tarefas pendentes';
        break;
      case FiltroTarefas.concluidas:
        titulo = 'Tarefas concluídas';
        break;
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF302A42),
            ),
          ),
        ),
        Text(
          '${tarefasVisiveis.length} ${tarefasVisiveis.length == 1 ? 'tarefa' : 'tarefas'}',
          style: const TextStyle(
            color: Color(0xFF858097),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _construirLista() {
    if (tarefasVisiveis.isEmpty) {
      final bool listaVazia = _tarefas.isEmpty;

      String mensagem;
      IconData icone;

      if (listaVazia) {
        mensagem = 'Sua lista está vazia';
        icone = Icons.note_add_outlined;
      } else if (_filtroAtual == FiltroTarefas.pendentes) {
        mensagem = 'Você não tem tarefas pendentes!';
        icone = Icons.celebration_outlined;
      } else if (_filtroAtual == FiltroTarefas.concluidas) {
        mensagem = 'Nenhuma tarefa concluída ainda.';
        icone = Icons.check_circle_outline_rounded;
      } else {
        mensagem = 'Nenhuma tarefa encontrada.';
        icone = Icons.search_off_rounded;
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEEEAF7)),
        ),
        child: Column(
          children: [
            Icon(
              icone,
              size: 46,
              color: const Color(0xFFAA9AD9),
            ),
            const SizedBox(height: 12),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF484158),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            if (listaVazia) ...[
              const SizedBox(height: 6),
              const Text(
                'Adicione sua primeira tarefa acima.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF858097),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: tarefasVisiveis.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final Tarefa tarefa = tarefasVisiveis[index];
        return _construirCartaoTarefa(tarefa);
      },
    );
  }

  Widget _construirCartaoTarefa(Tarefa tarefa) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tarefa.concluida
              ? const Color(0xFFDCEFE8)
              : const Color(0xFFEEEAF7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Checkbox(
              value: tarefa.concluida,
              onChanged: (_) => _alternarConclusao(tarefa),
              activeColor: const Color(0xFF37A889),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tarefa.titulo,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: tarefa.concluida
                            ? const Color(0xFF9994A6)
                            : const Color(0xFF373047),
                        decoration: tarefa.concluida
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          tarefa.concluida
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 13,
                          color: tarefa.concluida
                              ? const Color(0xFF37A889)
                              : const Color(0xFFE6A23C),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          tarefa.concluida ? 'Concluída' : 'Em andamento',
                          style: TextStyle(
                            fontSize: 11,
                            color: tarefa.concluida
                                ? const Color(0xFF37A889)
                                : const Color(0xFFB68532),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Excluir tarefa',
              onPressed: () => _excluirTarefa(tarefa),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFCC7888),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
