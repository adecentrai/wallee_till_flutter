import 'dart:convert';

import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'dart:async';
import 'models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalleeTillComm {
  TerminalConfiguration terminalConfiguration;
  Function onCharged;
  Function onCancel;
  Function onError;
  Function onNotification;
  Function onConnected;
  late StompClient stompClient;
  late SharedPreferences prefs;
  WalleeTillComm(
      {required TerminalConfiguration this.terminalConfiguration,
      required Function this.onCharged,
      required Function this.onCancel,
      required Function this.onError,
      required Function this.onNotification,
      required Function this.onConnected}) {
    Map<String, String> header = <String, String>{
      "token": terminalConfiguration.credential
    };
    stompClient = StompClient(
        config: StompConfig(
            url: 'wss://app-wallee.com/terminal-websocket',
            //webSocketConnectHeaders: header,
            stompConnectHeaders: header,
            beforeConnect: () async {
              prefs = await SharedPreferences.getInstance();
              prefs.remove("terminalMessages");
            },
            onStompError: (StompFrame s) {
              this.onError(Exception(s.body));
              stompClient.deactivate();
            },
            onConnect: onConnect,
            onDebugMessage: (s) {
              print(s);
            }));

    stompClient.activate();
  }
  cancel() {
    this.sendMessage("cancel");
  }

  disconnect() {
    stompClient.deactivate();
  }

  void onConnect(StompFrame s) async {
    //print(s.toString());

    SharedPreferences.getInstance();
    stompClient.subscribe(
        destination: '/user/terminal/message',
        callback: (frame) {
          receiveMessage(frame);
        });
    stompClient.subscribe(
        destination: '/user/terminal/errors',
        callback: (frame) {
          receiveError(frame);
        });
    this.onConnected();
  }

  receiveMessage(StompFrame f) {
    Map bodyDecoded = json.decode(f.body!);
    if (!isNewMessage(f.body!)) {
      return;
    }

    switch (bodyDecoded['type']) {
      case 'NOTIFICATION':
        {
          //sendMessage('cancel');
          this.onNotification(bodyDecoded);
          acknowledgeMessage(f);
        }
        break;
      case 'CHARGED':
        {
          this.onCharged(this.terminalConfiguration.transactionId);
          acknowledgeMessage(f);
          stompClient.deactivate();
          prefs.remove("terminalMessages");
        }
        break;
      case 'CANCELED':
        {
          this.onCancel();
          acknowledgeMessage(f);
          stompClient.deactivate();
          prefs.remove("terminalMessages");
        }
        break;
      case 'QUESTION':
        {
          acknowledgeMessage(f);
        }
        break;
    }
  }

  receiveError(StompFrame f) {
    this.onError();
    // print(f.headers);
    // print(f.body);
  }

  bool isNewMessage(String message) {
    List<String> messageList = prefs.getStringList("terminalMessages") ?? [];
    if (messageList.contains(message))
      return false;
    else
      messageList.add(message);

    prefs.setStringList("terminalMessages", messageList);
    return true;
  }

  acknowledgeMessage(StompFrame message) async {
    stompClient.ack(id: message.headers["messageId"]!, headers: {
      'token': this.terminalConfiguration.credential,
      'messageId': (message != null ? message.headers["messageId"] : null)!,
    });
  }

  sendMessage(String path, {StompFrame? message, Map? payload}) {
    final jsonEncoder = JsonEncoder();

    stompClient.send(
        destination: '/terminal-app/' + path,
        body: payload != null ? jsonEncoder.convert(payload) : null,
        headers: {
          'token': this.terminalConfiguration.credential,
          'messageId': (message != null ? message.headers["messageId"] : "")!,
        });
  }
}
