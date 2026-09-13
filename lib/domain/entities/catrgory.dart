class GetAllCategories {
  int? status;
  String? message;
  Data? data;
  String? error;

  GetAllCategories({this.status, this.message, this.data, this.error});

  GetAllCategories.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
    error = json['error'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    data['error'] = error;
    return data;
  }
}

class Data {
  List<ItemTypes>? itemTypes;

  Data({this.itemTypes});

  Data.fromJson(Map<String, dynamic> json) {
    if (json['itemTypes'] != null) {
      itemTypes = (json['itemTypes'] as List)
          .map((v) => ItemTypes.fromJson(v))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (itemTypes != null) {
      data['itemTypes'] = itemTypes!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class ItemTypes {
  int? id;
  String? name;
  String? description;
  String? status;
  dynamic image;
  String? farePerKm;
  String? mode;

  ItemTypes(
      {this.id,
      this.name,
      this.description,
      this.farePerKm,
      this.mode,
      this.status,
      this.image});

  ItemTypes.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    description = json['description'];
    status = json['status'];
    image = json['image'];
    farePerKm = json['fare_per_km'];
    mode = json['mode'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['description'] = description;
    data['status'] = status;
    data['image'] = image;
    data['fare_per_km'] = farePerKm;
    data['mode'] = mode;
    return data;
  }
}
