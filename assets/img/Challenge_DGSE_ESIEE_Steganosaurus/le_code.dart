// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as A;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:color/color.dart';

void main() => runApp(MyApp());

// #docregion MyApp
class MyApp extends StatelessWidget {
  // #docregion build
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Startup Name Generator',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File _image;
  final picker = ImagePicker();
  bool _btnEnabled = false;
  final myController = TextEditingController();
  String tempPath;

  Future getImage() async {
    final pickedFile = await picker.getImage(source: ImageSource.gallery);

    setState(() {
      _image = File(pickedFile.path);
    });
  }

  String MessageToBinaryString(String pMessage) {
    String Result;
    Result = "";
    List<int> bytes = utf8.encode(pMessage);
    bytes.forEach((item) {
      Result += item.toRadixString(2).padLeft(8, '0');
    });
    return Result;
  }

  Future<void> steggapp(File pImage, String pMessage) async {
    //Declaration
    String ImagePath;
    String binaryStringmessage;
    String binaryStringImage;
    String binaryStringData;
    Directory tempDir = await getTemporaryDirectory();
    tempPath = tempDir.path;
    print(tempPath);
    List<List<int>> DataList = List<List<int>>();

    //Initialisation

    //get the two binary string from parameters
    binaryStringmessage = MessageToBinaryString(pMessage);
    ImagePath = pImage.path;

    File image = new File(ImagePath);

    var decodedImage = await decodeImageFromList(image.readAsBytesSync());
    ByteData imgbyte = await decodedImage.toByteData();
    var imgintlist = imgbyte.buffer.asUint8List();

    A.Image aimage = A.Image.fromBytes(
        decodedImage.width, decodedImage.height, imgintlist,
        format: A.Format.rgba);
    A.Image resisedimage = A.copyResize(aimage, width: 1000);

    String RRGGBBString;
    String RedBinString;
    String BlueBinString;
    String GreenBinString;
    String PixelString;
    String MegaString;

    MegaString = "";
    for (int i = 0; i < resisedimage.length; i++) {
      RRGGBBString = resisedimage[i]
          .toRadixString(2)
          .padLeft(32, '0')
          .substring(8); // ByeBye l'Alpha
      PixelString = RRGGBBString.substring(16, 24) + // Rouge
          RRGGBBString.substring(8, 16) + // Vert
          RRGGBBString.substring(0, 8); // Bleu
      MegaString += PixelString;
    }
    int messaggelength = 0;
    String messagetohide = binaryStringmessage;
    String substringtoFind;
    substringtoFind = messagetohide.substring(0, 1);

    String Stringbuilttest = "";
    var offsetarray = new List();
    int offsettostore;
    int lengthtostore;
    int offset;
    String Megastringtosearch =
        MegaString.substring((MegaString.length / 4).round());
    //print("performing data calculation");
    while (messaggelength < binaryStringmessage.length) {
      offsettostore = Megastringtosearch.indexOf(substringtoFind);

      //print(Megastringtosearch.substring(offsettostore,offsettostore+substringtoFind.length));
      // offsettostore != -1, tant que indexOf trouve une suite
      // substringtoFind.length<=messagetohide.length-1, tant qu'on dépasse pas notre message
      while (offsettostore != -1 &&
          substringtoFind.length <= messagetohide.length - 1) {
        lengthtostore = substringtoFind
            .length; // on stocke la taille depuis la pos dans Megastringtosearch
        offset = offsettostore; // on stocke la position dans Megastringtosearch
        // tant qu'on trouve on ajoute un nouveau bit à trouver
        substringtoFind =
            messagetohide.substring(0, substringtoFind.length + 1);
        // notre chaîne de bit est trouvable dans Megastrintosearch, sinon indexOf retourne -A
        offsettostore = Megastringtosearch.indexOf(substringtoFind);
      }
      // Tout trouvé ?
      if (substringtoFind.length == messagetohide.length) {
        int lastoffsettostore = Megastringtosearch.indexOf(substringtoFind);
        // ça dépasse un peu?
        if (lastoffsettostore == -1) {
          // on stocke les résultats dans offsetarray + le bit qui dépasse
          offsetarray.add([offset, lengthtostore]);
          offsetarray.add([Megastringtosearch.indexOf(substringtoFind[-1]), 1]);
        }
        // ça dépasse pas:
        else {
          offsetarray.add([
            Megastringtosearch.indexOf(substringtoFind),
            substringtoFind.length
          ]);
          var lastitem = offsetarray.last;
        }
        //
        messaggelength += substringtoFind.length;
      }
      // on a trouvé qu'un bloc
      else {
        // on retire le bloc trouvé
        messagetohide = messagetohide.substring(substringtoFind.length - 1);
        messaggelength += substringtoFind.length;
        // on stocke le résultat
        offsetarray.add([offset, lengthtostore]);
        offsettostore = 0;
        lengthtostore = 1;
        offset = 0;
        // on recommence à trouver un nouveau bloc
        substringtoFind = messagetohide.substring(0, 1);
      }
    }

    int offsetdatasize = resisedimage.length * 8 * 3;

    int lenghtdatasize = binaryStringmessage.length;
    int lenghtsizebit = lenghtdatasize.toRadixString(2).length;
    ;
    int datasizebit = offsetdatasize.toRadixString(2).length;

    String stringtowrite = "";

    stringtowrite +=
        offsetarray.length.toRadixString(2).padLeft(datasizebit, '0') +
            lenghtsizebit.toRadixString(2).padLeft(datasizebit, '0');

    offsetarray.forEach((listofdata) {
//      listofdata.forEach((data){
//        print(data.toRadixString(2).padLeft(datasizebit,'0'));
      stringtowrite +=
          listofdata[0].toRadixString(2).padLeft(datasizebit, '0') +
              listofdata[1].toRadixString(2).padLeft(lenghtsizebit, '0');
    });
    int lengthofmodifiedstring = stringtowrite.length;
    List<int> pixelvalue = new List();
    int compteur = 0;
    int missingsize;

    String finaleImageString;
    finaleImageString =
        stringtowrite + MegaString.substring(stringtowrite.length);
    int limit;
    limit = stringtowrite.length;
    while (compteur < limit) {
      try {
        pixelvalue.add(int.parse(stringtowrite.substring(0, 8), radix: 2));
        stringtowrite = stringtowrite.substring(8);
        compteur += 8;
      } on RangeError {
        missingsize = 8 - stringtowrite.length;
        pixelvalue.add(int.parse(
            stringtowrite +
                finaleImageString.substring(compteur + stringtowrite.length,
                    compteur + stringtowrite.length + missingsize),
            radix: 2));
        compteur += 8;
      }
    }

    A.Image imagetosave;
    int compteurpixel;
    imagetosave = resisedimage.clone();
    compteurpixel = 0;
    List<int> lastpixellist = new List();
    for (int iz = 0; iz < pixelvalue.length; iz += 3) {
      try {
        var testpixel = pixelvalue[iz + 2];
        imagetosave.data[compteurpixel] =
            A.getColor(pixelvalue[iz], pixelvalue[iz + 1], pixelvalue[iz + 2]);
        compteurpixel += 1;
      } on RangeError {
        pixelvalue = pixelvalue.sublist(iz);
        var basixpixellist = imagetosave.data[compteurpixel]
            .toRadixString(2)
            .padLeft(32, '0')
            .substring(8);
        int RedChannelint =
            int.parse(basixpixellist.substring(16, 24), radix: 2);
        int GreenChannelint =
            int.parse(basixpixellist.substring(16, 24), radix: 2);
        int BlueChannelint =
            int.parse(basixpixellist.substring(16, 24), radix: 2);
        List<int> originalpixelvalue = [
          RedChannelint,
          GreenChannelint,
          BlueChannelint
        ];
        for (int ze = 0; ze <= 2; ze++) {
          if (ze > pixelvalue.length - 1) {
            lastpixellist.add(originalpixelvalue[ze]);
          } else {
            lastpixellist.add(pixelvalue[ze]);
          }
        }
        imagetosave.data[compteurpixel] =
            A.getColor(lastpixellist[0], lastpixellist[1], lastpixellist[2]);
      }
    }

    Directory documentD = await getExternalStorageDirectory();
    new File(documentD.path + '/thumbnail-test.png')
      ..writeAsBytesSync(A.encodePng(imagetosave));

    //binaryStringImage =ImageToBinary(pImage);
//
//    //calculate the list [numberofbytestoread,[offset,len],[offset,len],...]
//
//    DataList=stegalg(binaryStringmessage,binaryStringImage);
//
//    //convert DataList to binary Stream
//
//    binaryStringData=ListToBin(DataList);
//
//    //Apply this binary List to pixel Array
//    pixelArray=incorporateData(binaryStringData,binaryStringImage);
//
//    //Generate and save the image
//    Targetimage= GenerateImage(pixelArray);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Steganausorus App'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Text('Select the message you want to hide'),
          TextFormField(
            controller: myController,
            autovalidate: true,
            validator: (String txt) {
              bool isValid = txt.length >= 1;
              if (isValid != _btnEnabled) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _btnEnabled = txt.length >= 1;
                  });
                });
              }
            },
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              border: UnderlineInputBorder(),
              hintText: 'I am a very well hidden message',
            ),
          ),
          Text('Select the target Image :'),
          _image == null ? Text('No image selected.') : Image.file(_image),
          RaisedButton(
            onPressed: _btnEnabled == true && _image != null
                ? () {
                    steggapp(_image, myController.text);
                  }
                : null,
            child: const Text('Start Hide & seek game',
                style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: getImage,
        tooltip: 'Pick Image',
        child: Icon(Icons.add_a_photo),
      ),
    );
  }
}
