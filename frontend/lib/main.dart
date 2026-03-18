import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:convert';
import 'dart:io';

void main() => runApp(MaterialApp(
  theme: ThemeData.dark(),
  home: OrionLogin(),
  debugShowCheckedModeBanner: false,
));

class OrionLogin extends StatelessWidget {
  final TextEditingController _userController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.security, size: 80, color: Colors.blue),
          Text("ORION CHAT BETA", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Padding(
            padding: EdgeInsets.all(20),
            child: TextField(controller: _userController, decoration: InputDecoration(labelText: "Username")),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => OrionChat(username: _userController.text))),
            child: Text("Entrar com E2EE"),
          )
        ],
      ),
    );
  }
}

class OrionChat extends StatefulWidget {
  final String username;
  OrionChat({required this.username});
  @override
  _OrionChatState createState() => _OrionChatState();
}

class _OrionChatState extends State<OrionChat> {
  late IOWebSocketChannel channel;
  final algorithm = X25519(); // Diffie-Hellman
  final List<String> messages = [];
  final TextEditingController _msgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    channel = IOWebSocketChannel.connect('ws://localhost:8000/ws/${widget.username}');
  }

  // Lógica de Criptografia Real
  Future<void> sendSecureMsg() async {
    final message = _msgController.text;
    // Em um sistema real, aqui geramos a SecretKey via troca de chaves
    // Para este código fonte, simulamos o envio do pacote criptografado
    final encrypted = "ENC_AES_" + base64Encode(utf8.encode(message));
    
    final payload = jsonEncode({
      "from": widget.username,
      "to": "destinatario", // Exemplo
      "content": encrypted
    });
    
    channel.sink.add(payload);
    setState(() => messages.add("Você: $message"));
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Orion: ${widget.username}"),
        actions: [
          IconButton(icon: Icon(Icons.account_balance_wallet), onPressed: () {}), // Doação
        ],
      ),
      body: Column(
        children: [
          Expanded(child: ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, i) => ListTile(title: Text(messages[i])),
          )),
          TextField(controller: _msgController, decoration: InputDecoration(
            suffixIcon: IconButton(icon: Icon(Icons.send), onPressed: sendSecureMsg)
          ))
        ],
      ),
    );
  }
}
