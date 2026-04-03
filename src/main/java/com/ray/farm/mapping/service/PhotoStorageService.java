package com.ray.farm.mapping.service;

import java.io.IOException;
import java.time.Instant;

public interface PhotoStorageService {

    StoredPhotoObject storePhoto(long treeId, String originalFilename, String contentType, byte[] bytes) throws IOException;

    StoredPhotoAccess createPhotoAccess(String bucket, String key);

    void deletePhoto(String bucket, String key);

    record StoredPhotoObject(String bucket, String key) {
    }

    record StoredPhotoAccess(String url, Instant expiresAt) {
    }
}
