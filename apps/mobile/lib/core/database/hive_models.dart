/// Local Product model for offline storage
class LocalProduct {
  final String firestoreId;
  final String storeId;
  final String name;
  final String? description;
  final double price;
  final double? cost;
  final String? barcode;
  final String? categoryId;
  final String? subcategoryId;
  final Map<String, int> stockByLocation;
  final int? lowStockThreshold;
  final String? image;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSyncedAt;
  final bool needsSync;

  LocalProduct({
    required this.firestoreId,
    required this.storeId,
    required this.name,
    this.description,
    required this.price,
    this.cost,
    this.barcode,
    this.categoryId,
    this.subcategoryId,
    required this.stockByLocation,
    this.lowStockThreshold,
    this.image,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.lastSyncedAt,
    this.needsSync = false,
  });

  int getStockForLocation(String? locationId) {
    if (locationId == null) return getTotalStock();
    return stockByLocation[locationId] ?? 0;
  }

  int getTotalStock() {
    return stockByLocation.values.fold(0, (sum, stock) => sum + stock);
  }

  Map<String, dynamic> toJson() => {
    'firestoreId': firestoreId,
    'storeId': storeId,
    'name': name,
    'description': description,
    'price': price,
    'cost': cost,
    'barcode': barcode,
    'categoryId': categoryId,
    'subcategoryId': subcategoryId,
    'stockByLocation': stockByLocation,
    'lowStockThreshold': lowStockThreshold,
    'image': image,
    'isActive': isActive,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    'needsSync': needsSync,
  };

  factory LocalProduct.fromJson(Map<String, dynamic> json) => LocalProduct(
    firestoreId: json['firestoreId'] ?? '',
    storeId: json['storeId'] ?? '',
    name: json['name'] ?? '',
    description: json['description'],
    price: (json['price'] ?? 0).toDouble(),
    cost: json['cost']?.toDouble(),
    barcode: json['barcode'],
    categoryId: json['categoryId'],
    subcategoryId: json['subcategoryId'],
    stockByLocation: Map<String, int>.from(json['stockByLocation'] ?? {}),
    lowStockThreshold: json['lowStockThreshold'],
    image: json['image'],
    isActive: json['isActive'] ?? true,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    lastSyncedAt: json['lastSyncedAt'] != null ? DateTime.parse(json['lastSyncedAt']) : null,
    needsSync: json['needsSync'] ?? false,
  );

  LocalProduct copyWith({
    String? firestoreId,
    String? storeId,
    String? name,
    String? description,
    double? price,
    double? cost,
    String? barcode,
    String? categoryId,
    String? subcategoryId,
    Map<String, int>? stockByLocation,
    int? lowStockThreshold,
    String? image,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSyncedAt,
    bool? needsSync,
  }) => LocalProduct(
    firestoreId: firestoreId ?? this.firestoreId,
    storeId: storeId ?? this.storeId,
    name: name ?? this.name,
    description: description ?? this.description,
    price: price ?? this.price,
    cost: cost ?? this.cost,
    barcode: barcode ?? this.barcode,
    categoryId: categoryId ?? this.categoryId,
    subcategoryId: subcategoryId ?? this.subcategoryId,
    stockByLocation: stockByLocation ?? this.stockByLocation,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    image: image ?? this.image,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    needsSync: needsSync ?? this.needsSync,
  );
}

/// Local Category model
class LocalCategory {
  final String firestoreId;
  final String storeId;
  final String name;
  final String? parentId;
  final int order;
  final DateTime? createdAt;
  final DateTime? lastSyncedAt;
  final bool needsSync;

  LocalCategory({
    required this.firestoreId,
    required this.storeId,
    required this.name,
    this.parentId,
    required this.order,
    this.createdAt,
    this.lastSyncedAt,
    this.needsSync = false,
  });

  Map<String, dynamic> toJson() => {
    'firestoreId': firestoreId,
    'storeId': storeId,
    'name': name,
    'parentId': parentId,
    'order': order,
    'createdAt': createdAt?.toIso8601String(),
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    'needsSync': needsSync,
  };

  factory LocalCategory.fromJson(Map<String, dynamic> json) => LocalCategory(
    firestoreId: json['firestoreId'] ?? '',
    storeId: json['storeId'] ?? '',
    name: json['name'] ?? '',
    parentId: json['parentId'],
    order: json['order'] ?? 0,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    lastSyncedAt: json['lastSyncedAt'] != null ? DateTime.parse(json['lastSyncedAt']) : null,
    needsSync: json['needsSync'] ?? false,
  );
}

/// Local Store model
class LocalStore {
  final String firestoreId;
  final String name;
  final String businessType;
  final bool hasMultipleLocations;
  final String? logo;
  final String ownerId;
  final Map<String, dynamic> settings;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastSyncedAt;

  LocalStore({
    required this.firestoreId,
    required this.name,
    required this.businessType,
    required this.hasMultipleLocations,
    this.logo,
    required this.ownerId,
    required this.settings,
    required this.isActive,
    this.createdAt,
    this.lastSyncedAt,
  });

  Map<String, dynamic> toJson() => {
    'firestoreId': firestoreId,
    'name': name,
    'businessType': businessType,
    'hasMultipleLocations': hasMultipleLocations,
    'logo': logo,
    'ownerId': ownerId,
    'settings': settings,
    'isActive': isActive,
    'createdAt': createdAt?.toIso8601String(),
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
  };

  factory LocalStore.fromJson(Map<String, dynamic> json) => LocalStore(
    firestoreId: json['firestoreId'] ?? '',
    name: json['name'] ?? '',
    businessType: json['businessType'] ?? 'retail',
    hasMultipleLocations: json['hasMultipleLocations'] ?? false,
    logo: json['logo'],
    ownerId: json['ownerId'] ?? '',
    settings: Map<String, dynamic>.from(json['settings'] ?? {}),
    isActive: json['isActive'] ?? true,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    lastSyncedAt: json['lastSyncedAt'] != null ? DateTime.parse(json['lastSyncedAt']) : null,
  );
}

/// Local Store Location model
class LocalStoreLocation {
  final String firestoreId;
  final String storeId;
  final String name;
  final String address;
  final String phone;
  final bool isDefault;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastSyncedAt;

  LocalStoreLocation({
    required this.firestoreId,
    required this.storeId,
    required this.name,
    required this.address,
    required this.phone,
    required this.isDefault,
    required this.isActive,
    this.createdAt,
    this.lastSyncedAt,
  });

  Map<String, dynamic> toJson() => {
    'firestoreId': firestoreId,
    'storeId': storeId,
    'name': name,
    'address': address,
    'phone': phone,
    'isDefault': isDefault,
    'isActive': isActive,
    'createdAt': createdAt?.toIso8601String(),
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
  };

  factory LocalStoreLocation.fromJson(Map<String, dynamic> json) => LocalStoreLocation(
    firestoreId: json['firestoreId'] ?? '',
    storeId: json['storeId'] ?? '',
    name: json['name'] ?? '',
    address: json['address'] ?? '',
    phone: json['phone'] ?? '',
    isDefault: json['isDefault'] ?? false,
    isActive: json['isActive'] ?? true,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    lastSyncedAt: json['lastSyncedAt'] != null ? DateTime.parse(json['lastSyncedAt']) : null,
  );
}

/// Local Transaction model
class LocalTransaction {
  final String firestoreId;
  final String storeId;
  final String locationId;
  final String receiptNumber;
  final String? offlineReceiptNumber;
  final String? customerId;
  final String? customerName;
  final String staffId;
  final String staffName;
  final List<TransactionItemData> items;
  final double subtotal;
  final double taxRate;
  final double tax;
  final double total;
  final String paymentMethod;
  final double amountReceived;
  final double change;
  final DateTime createdAt;
  final bool isOfflineTransaction;
  final bool needsSync;
  final DateTime? syncedAt;

  LocalTransaction({
    required this.firestoreId,
    required this.storeId,
    required this.locationId,
    required this.receiptNumber,
    this.offlineReceiptNumber,
    this.customerId,
    this.customerName,
    required this.staffId,
    required this.staffName,
    required this.items,
    required this.subtotal,
    required this.taxRate,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.amountReceived,
    required this.change,
    required this.createdAt,
    this.isOfflineTransaction = false,
    this.needsSync = false,
    this.syncedAt,
  });

  /// Unique identifier (firestoreId or local receipt number)
  String get id => firestoreId.isNotEmpty ? firestoreId : receiptNumber;

  Map<String, dynamic> toJson() => {
    'firestoreId': firestoreId,
    'storeId': storeId,
    'locationId': locationId,
    'receiptNumber': receiptNumber,
    'offlineReceiptNumber': offlineReceiptNumber,
    'customerId': customerId,
    'customerName': customerName,
    'staffId': staffId,
    'staffName': staffName,
    'items': items.map((e) => e.toJson()).toList(),
    'subtotal': subtotal,
    'taxRate': taxRate,
    'tax': tax,
    'total': total,
    'paymentMethod': paymentMethod,
    'amountReceived': amountReceived,
    'change': change,
    'createdAt': createdAt.toIso8601String(),
    'isOfflineTransaction': isOfflineTransaction,
    'needsSync': needsSync,
    'syncedAt': syncedAt?.toIso8601String(),
  };

  factory LocalTransaction.fromJson(Map<String, dynamic> json) => LocalTransaction(
    firestoreId: json['firestoreId'] ?? '',
    storeId: json['storeId'] ?? '',
    locationId: json['locationId'] ?? '',
    receiptNumber: json['receiptNumber'] ?? '',
    offlineReceiptNumber: json['offlineReceiptNumber'],
    customerId: json['customerId'],
    customerName: json['customerName'],
    staffId: json['staffId'] ?? '',
    staffName: json['staffName'] ?? '',
    items: (json['items'] as List<dynamic>?)
        ?.map((e) => TransactionItemData.fromJson(e))
        .toList() ?? [],
    subtotal: (json['subtotal'] ?? 0).toDouble(),
    taxRate: (json['taxRate'] ?? 0.12).toDouble(),
    tax: (json['tax'] ?? 0).toDouble(),
    total: (json['total'] ?? 0).toDouble(),
    paymentMethod: json['paymentMethod'] ?? 'cash',
    amountReceived: (json['amountReceived'] ?? 0).toDouble(),
    change: (json['change'] ?? 0).toDouble(),
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    isOfflineTransaction: json['isOfflineTransaction'] ?? false,
    needsSync: json['needsSync'] ?? false,
    syncedAt: json['syncedAt'] != null ? DateTime.parse(json['syncedAt']) : null,
  );

  LocalTransaction copyWith({
    String? firestoreId,
    bool? needsSync,
    DateTime? syncedAt,
  }) => LocalTransaction(
    firestoreId: firestoreId ?? this.firestoreId,
    storeId: storeId,
    locationId: locationId,
    receiptNumber: receiptNumber,
    offlineReceiptNumber: offlineReceiptNumber,
    customerId: customerId,
    customerName: customerName,
    staffId: staffId,
    staffName: staffName,
    items: items,
    subtotal: subtotal,
    taxRate: taxRate,
    tax: tax,
    total: total,
    paymentMethod: paymentMethod,
    amountReceived: amountReceived,
    change: change,
    createdAt: createdAt,
    isOfflineTransaction: isOfflineTransaction,
    needsSync: needsSync ?? this.needsSync,
    syncedAt: syncedAt ?? this.syncedAt,
  );
}

/// Transaction Item data
class TransactionItemData {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final double subtotal;

  TransactionItemData({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'price': price,
    'quantity': quantity,
    'subtotal': subtotal,
  };

  factory TransactionItemData.fromJson(Map<String, dynamic> json) => TransactionItemData(
    productId: json['productId'] ?? '',
    name: json['name'] ?? '',
    price: (json['price'] ?? 0).toDouble(),
    quantity: json['quantity'] ?? 0,
    subtotal: (json['subtotal'] ?? 0).toDouble(),
  );
}

/// Local Stock History model
class LocalStockHistory {
  final String firestoreId;
  final String productId;
  final String productName;
  final String locationId;
  final String locationName;
  final int quantityAdded;
  final int previousStock;
  final int newStock;
  final String? notes;
  final String? userId;
  final String? userName;
  final DateTime createdAt;
  final bool needsSync;
  final DateTime? syncedAt;

  LocalStockHistory({
    required this.firestoreId,
    required this.productId,
    required this.productName,
    required this.locationId,
    required this.locationName,
    required this.quantityAdded,
    required this.previousStock,
    required this.newStock,
    this.notes,
    this.userId,
    this.userName,
    required this.createdAt,
    this.needsSync = false,
    this.syncedAt,
  });

  /// Unique identifier (firestoreId or generated from productId and createdAt)
  String get id => firestoreId.isNotEmpty ? firestoreId : 'local_${productId}_${createdAt.millisecondsSinceEpoch}';

  Map<String, dynamic> toJson() => {
    'firestoreId': firestoreId,
    'productId': productId,
    'productName': productName,
    'locationId': locationId,
    'locationName': locationName,
    'quantityAdded': quantityAdded,
    'previousStock': previousStock,
    'newStock': newStock,
    'notes': notes,
    'userId': userId,
    'userName': userName,
    'createdAt': createdAt.toIso8601String(),
    'needsSync': needsSync,
    'syncedAt': syncedAt?.toIso8601String(),
  };

  factory LocalStockHistory.fromJson(Map<String, dynamic> json) => LocalStockHistory(
    firestoreId: json['firestoreId'] ?? '',
    productId: json['productId'] ?? '',
    productName: json['productName'] ?? '',
    locationId: json['locationId'] ?? '',
    locationName: json['locationName'] ?? '',
    quantityAdded: json['quantityAdded'] ?? 0,
    previousStock: json['previousStock'] ?? 0,
    newStock: json['newStock'] ?? 0,
    notes: json['notes'],
    userId: json['userId'],
    userName: json['userName'],
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    needsSync: json['needsSync'] ?? false,
    syncedAt: json['syncedAt'] != null ? DateTime.parse(json['syncedAt']) : null,
  );

  LocalStockHistory copyWith({
    String? firestoreId,
    bool? needsSync,
    DateTime? syncedAt,
  }) => LocalStockHistory(
    firestoreId: firestoreId ?? this.firestoreId,
    productId: productId,
    productName: productName,
    locationId: locationId,
    locationName: locationName,
    quantityAdded: quantityAdded,
    previousStock: previousStock,
    newStock: newStock,
    notes: notes,
    userId: userId,
    userName: userName,
    createdAt: createdAt,
    needsSync: needsSync ?? this.needsSync,
    syncedAt: syncedAt ?? this.syncedAt,
  );
}

/// Sync Operation for queue
class SyncOperation {
  final String id;
  final String operationType;
  final String entityType;
  final String entityId;
  final String? firestoreId;
  final Map<String, dynamic> data;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final String status;

  SyncOperation({
    required this.id,
    required this.operationType,
    required this.entityType,
    required this.entityId,
    this.firestoreId,
    required this.data,
    this.retryCount = 0,
    this.lastError,
    required this.createdAt,
    this.lastAttemptAt,
    this.status = 'PENDING',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'operationType': operationType,
    'entityType': entityType,
    'entityId': entityId,
    'firestoreId': firestoreId,
    'data': data,
    'retryCount': retryCount,
    'lastError': lastError,
    'createdAt': createdAt.toIso8601String(),
    'lastAttemptAt': lastAttemptAt?.toIso8601String(),
    'status': status,
  };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
    id: json['id'] ?? '',
    operationType: json['operationType'] ?? '',
    entityType: json['entityType'] ?? '',
    entityId: json['entityId'] ?? '',
    firestoreId: json['firestoreId'],
    data: Map<String, dynamic>.from(json['data'] ?? {}),
    retryCount: json['retryCount'] ?? 0,
    lastError: json['lastError'],
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    lastAttemptAt: json['lastAttemptAt'] != null ? DateTime.parse(json['lastAttemptAt']) : null,
    status: json['status'] ?? 'PENDING',
  );

  SyncOperation copyWith({
    String? status,
    String? lastError,
    int? retryCount,
    DateTime? lastAttemptAt,
  }) => SyncOperation(
    id: id,
    operationType: operationType,
    entityType: entityType,
    entityId: entityId,
    firestoreId: firestoreId,
    data: data,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError ?? this.lastError,
    createdAt: createdAt,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    status: status ?? this.status,
  );
}

/// Local Cart model
class LocalCart {
  final String storeId;
  final List<CartItemData> items;
  final String? customerId;
  final String? customerName;
  final double taxRate;
  final DateTime updatedAt;

  LocalCart({
    required this.storeId,
    required this.items,
    this.customerId,
    this.customerName,
    required this.taxRate,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'storeId': storeId,
    'items': items.map((e) => e.toJson()).toList(),
    'customerId': customerId,
    'customerName': customerName,
    'taxRate': taxRate,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory LocalCart.fromJson(Map<String, dynamic> json) => LocalCart(
    storeId: json['storeId'] ?? '',
    items: (json['items'] as List<dynamic>?)
        ?.map((e) => CartItemData.fromJson(e))
        .toList() ?? [],
    customerId: json['customerId'],
    customerName: json['customerName'],
    taxRate: (json['taxRate'] ?? 0.12).toDouble(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
  );
}

/// Cart Item data
class CartItemData {
  final String productId;
  final String name;
  final double price;
  final String? image;
  final int quantity;

  CartItemData({
    required this.productId,
    required this.name,
    required this.price,
    this.image,
    required this.quantity,
  });

  double get subtotal => price * quantity;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'price': price,
    'image': image,
    'quantity': quantity,
  };

  factory CartItemData.fromJson(Map<String, dynamic> json) => CartItemData(
    productId: json['productId'] ?? '',
    name: json['name'] ?? '',
    price: (json['price'] ?? 0).toDouble(),
    image: json['image'],
    quantity: json['quantity'] ?? 1,
  );
}

/// Sync Status
class SyncStatus {
  final String storeId;
  final DateTime? lastFullSync;
  final DateTime? lastIncrementalSync;
  final int pendingOperationsCount;
  final bool isSyncing;
  final String? lastError;

  SyncStatus({
    required this.storeId,
    this.lastFullSync,
    this.lastIncrementalSync,
    this.pendingOperationsCount = 0,
    this.isSyncing = false,
    this.lastError,
  });

  Map<String, dynamic> toJson() => {
    'storeId': storeId,
    'lastFullSync': lastFullSync?.toIso8601String(),
    'lastIncrementalSync': lastIncrementalSync?.toIso8601String(),
    'pendingOperationsCount': pendingOperationsCount,
    'isSyncing': isSyncing,
    'lastError': lastError,
  };

  factory SyncStatus.fromJson(Map<String, dynamic> json) => SyncStatus(
    storeId: json['storeId'] ?? '',
    lastFullSync: json['lastFullSync'] != null ? DateTime.parse(json['lastFullSync']) : null,
    lastIncrementalSync: json['lastIncrementalSync'] != null ? DateTime.parse(json['lastIncrementalSync']) : null,
    pendingOperationsCount: json['pendingOperationsCount'] ?? 0,
    isSyncing: json['isSyncing'] ?? false,
    lastError: json['lastError'],
  );

  SyncStatus copyWith({
    DateTime? lastFullSync,
    DateTime? lastIncrementalSync,
    int? pendingOperationsCount,
    bool? isSyncing,
    String? lastError,
  }) => SyncStatus(
    storeId: storeId,
    lastFullSync: lastFullSync ?? this.lastFullSync,
    lastIncrementalSync: lastIncrementalSync ?? this.lastIncrementalSync,
    pendingOperationsCount: pendingOperationsCount ?? this.pendingOperationsCount,
    isSyncing: isSyncing ?? this.isSyncing,
    lastError: lastError,
  );
}

/// User session cache
class LocalUserSession {
  final String uid;
  final String email;
  final String? fullName;
  final String? displayName;
  final String? role;
  final String? storeId;
  final String? defaultLocationId;
  final DateTime cachedAt;

  LocalUserSession({
    required this.uid,
    required this.email,
    this.fullName,
    this.displayName,
    this.role,
    this.storeId,
    this.defaultLocationId,
    required this.cachedAt,
  });

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'fullName': fullName,
    'displayName': displayName,
    'role': role,
    'storeId': storeId,
    'defaultLocationId': defaultLocationId,
    'cachedAt': cachedAt.toIso8601String(),
  };

  factory LocalUserSession.fromJson(Map<String, dynamic> json) => LocalUserSession(
    uid: json['uid'] ?? '',
    email: json['email'] ?? '',
    fullName: json['fullName'],
    displayName: json['displayName'],
    role: json['role'],
    storeId: json['storeId'],
    defaultLocationId: json['defaultLocationId'],
    cachedAt: json['cachedAt'] != null ? DateTime.parse(json['cachedAt']) : DateTime.now(),
  );
}
