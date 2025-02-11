// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'package:dialogflow_grpc/dialogflow_grpc.dart';
import 'package:dialogflow_grpc/generated/google/cloud/dialogflow/v2beta1/session.pb.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sound_stream/sound_stream.dart';

class Chat extends StatefulWidget {
  const Chat({super.key});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final List<ChatMessage> _messages = <ChatMessage>[];
  final TextEditingController _textController = TextEditingController();

  bool _isRecording = false;

  RecorderStream _recorder = RecorderStream();
  late StreamSubscription _recorderStatus;
  late StreamSubscription<List<int>> _audioStreamSubscription;
  late BehaviorSubject<List<int>> _audioStream;

  late DialogflowGrpcV2Beta1 dialogflow;

  

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initPlugin();
  }

  void dispose(){
    _recorderStatus?.cancel();
    _audioStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> initPlugin() async{
    _recorderStatus = _recorder.status.listen((status){
      if(mounted)
        setState(() {
          _isRecording = status == SoundStreamStatus.Playing;
        });
    });

    await Future.wait([
      _recorder.initialize()
    ]);

    final serviceAccount = ServiceAccount.fromString(
        '${(await rootBundle.loadString('assets/credentials.json'))}');

     dialogflow = DialogflowGrpcV2Beta1.viaServiceAccount(serviceAccount);
  }

  void stopStream() async{
    await _recorder.stop();
    await _audioStreamSubscription?.cancel();
    await _audioStream?.close();
  }

  void handleSubmitted(text) async{
    print(text);
    _textController.clear();
    ChatMessage message = ChatMessage(
 text: text,
 name: "You",
 type: true,
);

DetectIntentResponse data = await dialogflow.detectIntent(text, 'en-US');
String fulfillmentText = data.queryResult.fulfillmentText;
if(fulfillmentText.isNotEmpty) {
  ChatMessage botMessage = ChatMessage(
    text: fulfillmentText,
    name: "Bot",
    type: false,
  );

  setState(() {
    _messages.insert(0, botMessage);
  });
}



setState(() {
 _messages.insert(0, message);
});
  }

  void handleStream() async{
    _recorder.start();
    _audioStream = BehaviorSubject<List<int>>();
    _audioStreamSubscription = _recorder.audioStream.listen((data){
      print(data);
      _audioStream.add(data);
    });
    // TODO Create SpeechContexts
    // Create an audio InputConfig
    var biasList = SpeechContextV2Beta1(
    phrases: [
      'Dialogflow CX',
      'Dialogflow Essentials',
      'Action Builder',
      'HIPAA'
    ],
    boost: 20.0
);

    // See: https://cloud.google.com/dialogflow/es/docs/reference/rpc/google.cloud.dialogflow.v2#google.cloud.dialogflow.v2.InputAudioConfig
var config = InputConfigV2beta1(
    encoding: 'AUDIO_ENCODING_LINEAR_16',
    languageCode: 'en-US',
    sampleRateHertz: 16000,
    singleUtterance: false,
    speechContexts: [biasList]
);

    // TODO Make the streamingDetectIntent call, with the InputConfig and the audioStream
    final responseStream = dialogflow.streamingDetectIntent(config, _audioStream);

    // Get the transcript and detectedIntent and show on screen
responseStream.listen((data) {
  //print('----');
  setState(() {
    //print(data);
    String transcript = data.recognitionResult.transcript;
    String queryText = data.queryResult.queryText;
    String fulfillmentText = data.queryResult.fulfillmentText;

    if(fulfillmentText.isNotEmpty) {

      ChatMessage message = new ChatMessage(
        text: queryText,
        name: "You",
        type: true,
      );

      ChatMessage botMessage = new ChatMessage(
        text: fulfillmentText,
        name: "Bot",
        type: false,
      );

      _messages.insert(0, message);
      _textController.clear();
      _messages.insert(0, botMessage);

    }
    if(transcript.isNotEmpty) {
      _textController.text = transcript;
    }

  });
},onError: (e){
  //print(e);
},onDone: () {
  //print('done');
});
    // TODO Get the transcript and detectedIntent and show on screen  
  }

  

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Flexible(child: ListView.builder(
          padding: EdgeInsets.all( 8.0 ),
          reverse: true,
          itemBuilder: (_, int index) => _messages[index],
          itemCount: _messages.length,       )),

          Divider(height: 1.0,),
          Container(
            decoration: BoxDecoration(color: Theme.of(context ).cardColor),
            child: IconTheme(
              data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Flexible(child: TextField(
                      controller: _textController,
                      onSubmitted: handleSubmitted,
                      decoration: InputDecoration.collapsed(hintText: 'Send a message'),
                    )),

                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 4.0),
                      child: IconButton(
                        onPressed: () => handleSubmitted(_textController.text), 
                        icon: Icon(Icons.send)),
                    ),

                    IconButton(
                      onPressed: _isRecording ? stopStream : handleStream, 
                      icon: Icon(_isRecording ? Icons.mic_off : Icons.mic),
                      iconSize: 30.0,)
                  ],
                ),
              ),
            ),
          )
      ],
    );
  }
}


//------------------------------------------------------------------------------------
// The chat message balloon
//
//------------------------------------------------------------------------------------

class ChatMessage extends StatelessWidget {
  ChatMessage({required this.text, required this.name, required this.type});

  final String text;
  final String name;
  final bool type;

  List<Widget> otherMessage(context){
    return [
      new Container(
        margin: const EdgeInsets.only(right: 16.0),
        child: CircleAvatar(child: new Text('B'),),
      ),

      new Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(this.name,
          style: TextStyle(fontWeight: FontWeight.bold),),

          Container(
            margin: const EdgeInsets.only(top: 5.0),
            child: Text(text),
          )
        ],
      ))
    ];
  }

  List<Widget> myMessage(context){
    return <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment:  CrossAxisAlignment.end,
          children: [
            Text(this.name,
            style: Theme.of(context).textTheme.titleMedium,),
            Container(
              margin: const EdgeInsets.only(top: 5.0),
              child: Text(text),
            )
          ],
        ),
      ),
      Container(
        margin: EdgeInsets.only(left: 16.0),
        child: CircleAvatar(
          child: Text(
            this.name[0],
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: this.type ? myMessage(context) : otherMessage(context),
      ),
    );
  }
}