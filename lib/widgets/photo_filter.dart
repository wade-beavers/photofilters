import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imageLib;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photofilters/filters/filters.dart';
import 'package:shimmer/shimmer.dart';

class PhotoFilter extends StatelessWidget {
  final imageLib.Image image;
  final String filename;
  final Filter filter;
  final BoxFit fit;
  final Widget loader;

  PhotoFilter({
    required this.image,
    required this.filename,
    required this.filter,
    this.fit = BoxFit.cover,
    this.loader = const Center(child: CircularProgressIndicator()),
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: compute(applyFilter, <String, dynamic>{
        "filter": filter,
        "image": image,
        "filename": filename,
      }),
      builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            return loader;
          case ConnectionState.active:
          case ConnectionState.waiting:
            return loader;
          case ConnectionState.done:
            if (snapshot.hasError)
              return Center(child: Text('Error: ${snapshot.error}'));
            return Image.memory(
              snapshot.data as dynamic,
              fit: fit,
            );
        }
      },
    );
  }
}

class PhotoFilterSelector extends StatefulWidget {
  final Widget title;
  final Widget subtitle;
  final Color appBarColor;
  final List<Filter> filters;
  final List<imageLib.Image> images;
  final Widget loader;
  final BoxFit fit;
  final List<String> filenames;
  final bool circleShape;

  const PhotoFilterSelector({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.filters,
    required this.images,
    this.appBarColor = Colors.blue,
    this.loader = const Center(child: CircularProgressIndicator()),
    this.fit = BoxFit.cover,
    required this.filenames,
    this.circleShape = false,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => new _PhotoFilterSelectorState();
}

class _PhotoFilterSelectorState extends State<PhotoFilterSelector> {
  String? filename;
  Map<String, List<int>?> cachedFilters = {};
  imageLib.Image? image;
  late bool loading;
  ValueNotifier<int> imageIndex = ValueNotifier<int>(0);
  List<Filter> selectedFilters = [];
  List<ValueNotifier<Filter?>> filterNotifiers = [];

  @override
  void initState() {
    super.initState();
    loading = false;
    filename = widget.filenames[imageIndex.value];
    image = widget.images[imageIndex.value];
    for (int i = 0; i < widget.images.length; i++) {
      selectedFilters.add(widget.filters[0]);
      filterNotifiers.add(ValueNotifier<Filter?>(widget.filters[0]));
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.appBarColor,
      appBar: AppBar(
        centerTitle: true,
        title: widget.title,
        backgroundColor: widget.appBarColor,
        elevation: 0,
        actions: <Widget>[
          loading
              ? Container()
              : IconButton(
                  icon: Icon(Icons.check),
                  onPressed: () async {
                    setState(() {
                      loading = true;
                    });
                    await saveAllFilteredImage();
                    Navigator.pop(context);
                  },
                )
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: loading
            ? widget.loader
            : Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  widget.subtitle,
                  ValueListenableBuilder<int>(
                    valueListenable: imageIndex,
                    builder: (BuildContext context, int index, Widget? child) {
                      image = widget.images[index];
                      filename = widget.filenames[index];
                      return Expanded(
                        flex: 6,
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          padding: EdgeInsets.all(12.0),
                          child: ValueListenableBuilder<Filter?>(
                            valueListenable: filterNotifiers[imageIndex.value],
                            builder: (BuildContext context, Filter? filter,
                                Widget? child) {
                              return _buildFilteredImage(
                                  filter, image, filename, imageIndex);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Visibility(
                          visible: imageIndex.value > 0,
                          child: ElevatedButton(
                            onPressed: () {
                              if (imageIndex.value > 0) {
                                setState(() {
                                  imageIndex.value--;
                                  filename = widget.filenames[imageIndex.value];
                                  image = widget.images[imageIndex.value];
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              shape: CircleBorder(),
                              padding: EdgeInsets.all(20),
                              backgroundColor: Color(0xFF4A4A4A),
                              foregroundColor: Colors.white,
                            ),
                            child: Icon(Icons.arrow_back_ios_rounded),
                          ),
                        ),
                        Visibility(
                          visible: imageIndex.value < widget.images.length - 1,
                          child: ElevatedButton(
                            onPressed: () {
                              if (imageIndex.value < widget.images.length - 1) {
                                setState(() {
                                  imageIndex.value++;
                                  filename = widget.filenames[imageIndex.value];
                                  image = widget.images[imageIndex.value];
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              shape: CircleBorder(),
                              padding: EdgeInsets.all(20),
                              backgroundColor: Color(0xFF4A4A4A),
                              foregroundColor: Colors.white,
                            ),
                            child: Icon(Icons.arrow_forward_ios_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.filters.length,
                        itemBuilder: (BuildContext context, int index) {
                          return InkWell(
                            child: Container(
                              padding: EdgeInsets.all(5.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  _buildFilterThumbnail(widget.filters[index],
                                      image, filename, imageIndex),
                                  SizedBox(
                                    height: 5.0,
                                  ),
                                  Text(
                                    widget.filters[index].name,
                                  )
                                ],
                              ),
                            ),
                            onTap: () => setState(() {
                              selectedFilters[imageIndex.value] =
                                  widget.filters[index];
                              filterNotifiers[imageIndex.value].value =
                                  widget.filters[index];
                            }),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  _buildFilterThumbnail(Filter filter, imageLib.Image? image, String? filename,
      ValueNotifier<int> imageIndex) {
    String cacheKey = '${filter.name}_${imageIndex.value}';
    if (cachedFilters[cacheKey] == null) {
      return FutureBuilder<List<int>>(
        future: compute(applyFilter, <String, dynamic>{
          "filter": filter,
          "image": image,
          "filename": filename,
        }),
        builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.active:
            case ConnectionState.waiting:
              return ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: SizedBox(
                  width: 125.0,
                  height: 125.0,
                  child: Shimmer(
                    child: Container(
                      width: 125.0,
                      height: 125.0,
                      color: Colors.white,
                    ),
                    gradient: LinearGradient(
                      colors: [Colors.grey, Colors.white, Colors.grey],
                    ),
                  ),
                ),
              );
            case ConnectionState.done:
              if (snapshot.hasError)
                return Center(child: Text('Error: ${snapshot.error}'));
              cachedFilters[cacheKey] = snapshot.data;
              return ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: Container(
                  width: 125.0,
                  height: 125.0,
                  color: Colors.white,
                  child: Image.memory(
                    snapshot.data as dynamic,
                    fit: BoxFit.cover,
                  ),
                ),
              );
          }
          // unreachable
        },
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6.0),
        child: Container(
          width: 125.0,
          height: 125.0,
          color: Colors.white,
          child: Image.memory(
            cachedFilters[cacheKey] as dynamic,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    Filter? currentFilter = selectedFilters[imageIndex.value];
    return File('$path/filtered_${currentFilter.name}_$filename');
  }

  Future<void> saveAllFilteredImage() async {
    for (int i = 0; i < widget.images.length; i++) {
      imageIndex.value = i;
      Filter? currentFilter = selectedFilters[i];
      String cacheKey = '${currentFilter.name}_${imageIndex.value}';
      List<int>? imageData = cachedFilters[cacheKey];

      if (imageData != null) {
        final result = await ImageGallerySaver.saveImage(
            Uint8List.fromList(imageData),
            quality: 100,
            name: 'filtered_${currentFilter.name}_${widget.filenames[i]}');
        print('File saved: $result');
      }
    }
  }

  Future<File> saveFilteredImage() async {
    var imageFile = await _localFile;
    Filter? currentFilter = selectedFilters[imageIndex.value];
    await imageFile.writeAsBytes(cachedFilters[currentFilter.name]!);
    return imageFile;
  }

  Widget _buildFilteredImage(Filter? filter, imageLib.Image? image,
      String? filename, ValueNotifier<int> imageIndex) {
    return ValueListenableBuilder<int>(
      valueListenable: imageIndex,
      builder: (context, index, child) {
        return filter != null
            ? _imageBuilder(
                filter, widget.images[index], widget.filenames[index])
            : Container();
      },
    );
  }

  Widget _imageBuilder(Filter filter, imageLib.Image? image, String? filename) {
    String cacheKey = '${filter.name}_${imageIndex.value}';
    if (cachedFilters[cacheKey] == null) {
      return FutureBuilder<List<int>>(
        future: compute(applyFilter, <String, dynamic>{
          "filter": filter,
          "image": image,
          "filename": filename,
        }),
        builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.active:
            case ConnectionState.waiting:
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    height: 300,
                    child: Shimmer(
                      child: Container(
                        width: double.infinity,
                        height: 300.0,
                        color: Colors.white,
                      ),
                      gradient: LinearGradient(
                        colors: [Colors.grey, Colors.white, Colors.grey],
                      ),
                    ),
                  ),
                ],
              );
            case ConnectionState.done:
              if (snapshot.hasError)
                return Center(child: Text('Error: ${snapshot.error}'));
              cachedFilters[cacheKey] = snapshot.data;
              return widget.circleShape
                  ? SizedBox(
                      height: MediaQuery.of(context).size.width / 3,
                      width: MediaQuery.of(context).size.width / 3,
                      child: Center(
                        child: CircleAvatar(
                          radius: MediaQuery.of(context).size.width / 3,
                          backgroundImage: MemoryImage(
                            snapshot.data as dynamic,
                          ),
                        ),
                      ),
                    )
                  : Image.memory(
                      snapshot.data as dynamic,
                      fit: BoxFit.contain,
                    );
          }
          // unreachable
        },
      );
    } else {
      return widget.circleShape
          ? SizedBox(
              height: MediaQuery.of(context).size.width / 3,
              width: MediaQuery.of(context).size.width / 3,
              child: Center(
                child: CircleAvatar(
                  radius: MediaQuery.of(context).size.width / 3,
                  backgroundImage: MemoryImage(
                    cachedFilters[cacheKey] as dynamic,
                  ),
                ),
              ),
            )
          : Image.memory(
              cachedFilters[cacheKey] as dynamic,
              fit: widget.fit,
            );
    }
  }
}

///The global applyfilter function
FutureOr<List<int>> applyFilter(Map<String, dynamic> params) {
  Filter? filter = params["filter"];
  imageLib.Image image = params["image"];
  String filename = params["filename"];
  List<int> _bytes = image.getBytes();
  if (filter != null) {
    filter.apply(_bytes as dynamic, image.width, image.height);
  }
  imageLib.Image _image =
      imageLib.Image.fromBytes(image.width, image.height, _bytes);
  _bytes = imageLib.encodeNamedImage(_image, filename)!;

  return _bytes;
}

///The global buildThumbnail function
FutureOr<List<int>> buildThumbnail(Map<String, dynamic> params) {
  int? width = params["width"];
  params["image"] = imageLib.copyResize(params["image"], width: width);
  return applyFilter(params);
}
