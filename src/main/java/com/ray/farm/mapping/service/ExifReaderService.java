package com.ray.farm.mapping.service;

import com.drew.imaging.ImageMetadataReader;
import com.drew.imaging.ImageProcessingException;
import com.drew.metadata.Metadata;
import com.drew.metadata.exif.GpsDirectory;
import com.ray.farm.mapping.config.StorageConfig;
import com.ray.farm.mapping.model.ItemGeoRecord;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.stereotype.Service;

import java.io.File;
import java.io.IOException;
import java.nio.file.Path;

@Service
public class ExifReaderService {

    public static final int WGS84_SRID = 4326; //Standard for lon, lat usage, doesnt need to mimic basemap projection
    private final Path photosDir;
    private static final GeometryFactory geometryFactory =
            new GeometryFactory(new PrecisionModel(), WGS84_SRID);


    public ExifReaderService(StorageConfig config) {
        this.photosDir = Path.of(config.photosDir()).toAbsolutePath().normalize();
    }


    public ItemGeoRecord getExifData(String photoFileName) throws IOException, ImageProcessingException {

        Path imagePath = photosDir.resolve(photoFileName);
        File file = imagePath.toFile();

        Metadata metadata = ImageMetadataReader.readMetadata(file);

        GpsDirectory gpsDir = metadata.getFirstDirectoryOfType(GpsDirectory.class);

        double lat = gpsDir.getGeoLocation().getLatitude();
        double lon = gpsDir.getGeoLocation().getLongitude();

        return new ItemGeoRecord(createPoint(lon, lat));

    }

    public static Point createPoint(double lon, double lat) {
        Point p = geometryFactory.createPoint(new Coordinate(lon, lat)); // x=lon, y=lat
        p.setSRID(WGS84_SRID);
        return p;
    }


}
