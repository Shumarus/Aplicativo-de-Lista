import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ----------------------------------------------------------------------
// CONFIGURAÇÕES GERAIS E INICIALIZAÇÃO
// ----------------------------------------------------------------------
const String baseUrl = 'https://barra.cos.ufrj.br/t5/rest';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Tarefas UFRJ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF4DD0E1)),
      home: const LoginScreen(),
    );
  }
}

// ----------------------------------------------------------------------
// MODELOS
// ----------------------------------------------------------------------
class Tarefa {
  String nome;
  bool concluida;
  bool isApagando;
  Timer? timerExclusao;

  Tarefa({
    required this.nome,
    this.concluida = false,
    this.isApagando = false,
  });

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'concluida': concluida,
  };

  factory Tarefa.fromJson(Map<String, dynamic> json) => Tarefa(
    nome: json['nome'] ?? '',
    concluida: json['concluida'] ?? false,
  );
}

// ----------------------------------------------------------------------
// TELA DE LOGIN
// ----------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _fazerLogin() async {
    final email = _emailCtrl.text.trim();
    final senha = _senhaCtrl.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      _showMsg('Preencha email e senha');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/rpc/fazer_login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'senha': senha}),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        String token = '';
        try {
          final parsedLogin = jsonDecode(res.body);
          if (parsedLogin is Map && parsedLogin.containsKey('token')) {
            token = parsedLogin['token'];
          } else if (parsedLogin is Map && parsedLogin.containsKey('jwt')) {
            token = parsedLogin['jwt'];
          } else if (parsedLogin is String) {
            token = parsedLogin;
          } else {
            token = res.body.replaceAll('"', '').trim();
          }
        } catch (e) {
          token = res.body.replaceAll('"', '').trim();
        }

        if (token.isNotEmpty && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TaskScreen(token: token, email: email),
            ),
          );
        } else {
          _showMsg('Falha ao extrair token.');
        }
      } else {
        _showMsg('Erro no login: Usuário ou senha inválidos.');
      }
    } catch (e) {
      _showMsg('Erro de conexão: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _senhaCtrl,
                decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _fazerLogin,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      child: const Text('Entrar'),
                    ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CadastroScreen()));
                },
                child: const Text('Não tem conta? Cadastre-se'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// TELA DE CADASTRO
// ----------------------------------------------------------------------
class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _celularCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmaSenhaCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _registrar() async {
    // Mantemos a validação no front-end
    if (_senhaCtrl.text != _confirmaSenhaCtrl.text) {
      _showMsg('As senhas não coincidem!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/rpc/registra_usuario'),
        headers: {'Content-Type': 'application/json'},
        // CORREÇÃO: Enviando apenas os campos que o banco de dados espera
        body: jsonEncode({
          'nome': _nomeCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'senha': _senhaCtrl.text.trim(),
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        _showMsg('Usuário cadastrado com sucesso!');
        if (mounted) Navigator.pop(context); // Volta pro Login
      } else {
        final erroMsg = res.body.contains('O email já está em uso') 
            ? 'Este e-mail já está em uso.' 
            : 'Erro ao cadastrar (${res.statusCode})';
        _showMsg(erroMsg);
      }
    } catch (e) {
      _showMsg('Erro de conexão: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            TextField(controller: _celularCtrl, decoration: const InputDecoration(labelText: 'Celular', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextField(controller: _senhaCtrl, decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 12),
            TextField(controller: _confirmaSenhaCtrl, decoration: const InputDecoration(labelText: 'Confirmar Senha', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _registrar,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: const Text('Cadastrar'),
                  ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// TELA PRINCIPAL (LISTA DE TAREFAS INTEGRADA)
// ----------------------------------------------------------------------
class TaskScreen extends StatefulWidget {
  final String token;
  final String email;

  const TaskScreen({super.key, required this.token, required this.email});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final List<Tarefa> taskList = [];
  final textController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTarefas();
  }

  // --- INTERCEPTADOR DE EXPIRAÇÃO DE TOKEN (5 MINUTOS) ---
  void _forceLoginExpirado() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sessão expirada. Por favor, faça login novamente.'), backgroundColor: Colors.red),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // --- COMUNICAÇÃO COM API ---
  Future<void> _fetchTarefas() async {
    try {
      final url = Uri.parse('$baseUrl/tarefas?email=eq.${Uri.encodeComponent(widget.email)}');
      final res = await http.get(url, headers: {'Authorization': 'Bearer ${widget.token}'});

      if (res.statusCode == 401) {
        return _forceLoginExpirado();
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        // Se for a primeira vez do usuário, a lista volta vazia -> cria o registro
        if (data is List && data.isEmpty) {
          final resPost = await http.post(
            Uri.parse('$baseUrl/tarefas'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
            body: jsonEncode({'email': widget.email, 'valor': []}),
          );
          if (resPost.statusCode == 401) return _forceLoginExpirado();
          
          if (mounted) setState(() => _isLoading = false);
        } else if (data is List && data.isNotEmpty) {
          final List valor = data.first['valor'] ?? [];
          setState(() {
            taskList.clear();
            taskList.addAll(valor.map((e) => Tarefa.fromJson(e)).toList());
            _organizarTarefas();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _syncTarefas() async {
    try {
      final url = Uri.parse('$baseUrl/tarefas?email=eq.${Uri.encodeComponent(widget.email)}');
      final res = await http.patch(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
        body: jsonEncode({'valor': taskList.map((t) => t.toJson()).toList()}),
      );

      if (res.statusCode == 401) {
        _forceLoginExpirado();
      }
    } catch (e) {
      debugPrint('Erro ao sincronizar: $e');
    }
  }

  // --- LÓGICA LOCAL DA LISTA ---
  void _addTask(String st) {
    final String novaTarefa = st.trim();
    if (novaTarefa.isEmpty) return;

    if (taskList.any((tarefa) => tarefa.nome.toLowerCase() == novaTarefa.toLowerCase())) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A tarefa "$novaTarefa" já existe na lista'), backgroundColor: const Color(0xFF757575), duration: const Duration(seconds: 2)),
      );
      return;
    }

    setState(() {
      taskList.add(Tarefa(nome: novaTarefa));
      _organizarTarefas();
      textController.clear();
    });
    _syncTarefas(); // Atualiza backend
  }

  void _organizarTarefas() {
    taskList.sort((a, b) {
      if (a.concluida == b.concluida) return 0;
      return a.concluida ? 1 : -1;
    });
  }

  void _concluirTarefa(Tarefa tarefa) {
    setState(() {
      taskList.remove(tarefa);
      tarefa.concluida = true;
      int primeiraConcluida = taskList.indexWhere((t) => t.concluida);
      if (primeiraConcluida == -1) {
        taskList.add(tarefa);
      } else {
        taskList.insert(primeiraConcluida, tarefa);
      }
    });
    _syncTarefas(); // Atualiza backend
  }

  void _desmarcarTarefa(Tarefa tarefa) {
    setState(() {
      taskList.remove(tarefa);
      tarefa.concluida = false;
      int primeiraConcluida = taskList.indexWhere((t) => t.concluida);
      if (primeiraConcluida == -1) {
        taskList.add(tarefa);
      } else {
        taskList.insert(primeiraConcluida, tarefa);
      }
    });
    _syncTarefas(); // Atualiza backend
  }

  void _iniciarExclusao(Tarefa tarefa) {
    setState(() {
      tarefa.isApagando = true;
    });
    tarefa.timerExclusao?.cancel();

    tarefa.timerExclusao = Timer(const Duration(seconds: 3), () {
      if (mounted && tarefa.isApagando) {
        setState(() {
          taskList.remove(tarefa);
        });
        _syncTarefas(); // Atualiza backend após apagar de fato
      }
    });
  }

  void _cancelarExclusao(Tarefa tarefa) {
    setState(() {
      tarefa.isApagando = false;
    });
    tarefa.timerExclusao?.cancel();
  }

  @override
  void dispose() {
    textController.dispose();
    for (var tarefa in taskList) {
      tarefa.timerExclusao?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF0277BD),
        title: const Text('Tarefas com Swipe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            tooltip: 'Sair',
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: textController,
                  onSubmitted: _addTask,
                  decoration: const InputDecoration(
                    labelText: 'Nova Tarefa',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: FloatingActionButton(
                  onPressed: () => _addTask(textController.text),
                  tooltip: 'Adicionar tarefa',
                  child: const Icon(Icons.add),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: taskList.length,
                  itemBuilder: (context, index) {
                    var apagar = true;
                    Completer<bool?> apertouBotao = Completer();
                    final item = taskList[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Dismissible(
                        key: Key('${item.nome}-${DateTime.now().millisecondsSinceEpoch}'), // Chave dinâmica evita erros de render ao desfazer
                        direction: DismissDirection.horizontal,
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            if (!item.concluida) {
                              _concluirTarefa(item);
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${item.nome} concluída!'), duration: const Duration(seconds: 2)),
                              );
                            }
                            return false;
                          }

                          apagar = true;
                          apertouBotao = Completer();

                          return Future.any([
                            Future.delayed(const Duration(seconds: 3), () => apagar),
                            apertouBotao.future,
                          ]);
                        },
                        background: Container(
                          decoration: BoxDecoration(color: const Color(0xFF43A047), borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.check, color: Colors.white, size: 30),
                        ),
                        secondaryBackground: Container(
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: IconButton(
                            onPressed: () {
                              apagar = false;
                              if (!apertouBotao.isCompleted) {
                                apertouBotao.complete(false);
                              }
                            },
                            icon: const Icon(Icons.clear, color: Colors.white),
                          ),
                        ),
                        onDismissed: (direction) {
                          if (direction == DismissDirection.endToStart) {
                            setState(() {
                              taskList.remove(item);
                            });
                            _syncTarefas(); // Atualiza backend ao remover pelo swipe

                            ScaffoldMessenger.of(context).clearSnackBars();
                            final snackBarController = ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${item.nome} removido'),
                                action: SnackBarAction(
                                  label: 'Desfazer',
                                  onPressed: () {
                                    setState(() {
                                      int posicao = index;
                                      if (posicao > taskList.length) posicao = taskList.length;
                                      taskList.insert(posicao, item);
                                      _organizarTarefas();
                                    });
                                    _syncTarefas(); // Atualiza backend ao restaurar
                                  },
                                ),
                              ),
                            );

                            Future.delayed(const Duration(seconds: 3), () {
                              snackBarController.close();
                            });
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: item.isApagando
                                ? Colors.red
                                : (index % 2 == 0 ? const Color(0xFFB3E5FC) : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey, width: 1),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                            leading: Checkbox(
                              value: item.concluida,
                              onChanged: item.isApagando ? null : (bool? valor) {
                                if (valor == true) {
                                  _concluirTarefa(item);
                                } else {
                                  _desmarcarTarefa(item);
                                }
                              },
                            ),
                            title: Text(
                              item.nome,
                              style: TextStyle(
                                fontSize: 16,
                                decoration: item.concluida ? TextDecoration.lineThrough : TextDecoration.none,
                                color: item.isApagando ? Colors.white : (item.concluida ? Colors.grey : Colors.black),
                              ),
                            ),
                            trailing: item.isApagando
                                ? IconButton(
                                    icon: const Icon(Icons.undo, color: Colors.white),
                                    tooltip: 'Desfazer',
                                    onPressed: () => _cancelarExclusao(item),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Apagar',
                                    onPressed: () => _iniciarExclusao(item),
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}
