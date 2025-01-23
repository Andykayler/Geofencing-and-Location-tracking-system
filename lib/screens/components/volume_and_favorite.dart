import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';

class VolumeAndFavorite extends StatelessWidget {
  const VolumeAndFavorite({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Stack(
              alignment: Alignment.center,
              children: const [
                CircularProgressIndicator(
                  value: 0.4,
                  color: Colors.white,
                  backgroundColor: grayColor,
                  strokeWidth: 1.2,
                ),
                Icon(
                  CupertinoIcons.speaker_2_fill,
                  color: grayColor,
                  size: 14,
                ),
              ],
            ),
          ),
          Container(
            height: 24,
            width: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: grayColor, width: 1.2),
            ),
            child: const Icon(
              CupertinoIcons.heart,
              color: grayColor,
              size: 14,
            ),
          )
        ],
      ),
    );
  }
}
