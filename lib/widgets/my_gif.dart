// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:gif_view/gif_view.dart';

class MyGif extends StatefulWidget {
  const MyGif({
    super.key,
    required this.image,
    required this.callback,
    required this.controller,
    this.loop = false,
    this.autoPlay = false,
  });
  final String image;
  final Function callback;
  final GifController controller;
  final bool loop;
  final bool autoPlay;

  @override
  State<MyGif> createState() => _MyGifState();
}

class _MyGifState extends State<MyGif> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {});
  }

  @override
  void dispose() {
    // TODO: implement dispose
    print('${widget.image} 디스포즈됨');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GifView(
      image: AssetImage(widget.image),
      controller: widget.controller,
      frameRate: 24,
      loop: widget.loop,
      onFinish: () {
        widget.callback();
        // print('${widget.image.split('/').last} onFinish.');
      },
      fadeDuration: Duration.zero,
      autoPlay: widget.autoPlay,
      progressBuilder: (context) => Image.asset('assets/img/wash_loading.png'),
    );
  }
}
