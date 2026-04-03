package com.ray.farm.mapping.service;

import com.drew.imaging.ImageMetadataReader;
import com.drew.imaging.ImageProcessingException;
import com.drew.metadata.Metadata;
import com.drew.metadata.exif.ExifSubIFDDirectory;
import com.drew.metadata.exif.GpsDirectory;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.stereotype.Service;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.time.Instant;
import java.util.Date;

@Service
public class ExifReaderService {

    public static final int WGS84_SRID = 4326; //Standard for lon, lat usage, doesnt need to mimic basemap projection
    private static final GeometryFactory geometryFactory =
            new GeometryFactory(new PrecisionModel(), WGS84_SRID);

    public ExifMetadata readMetadata(byte[] imageBytes) throws IOException, ImageProcessingException {
        Metadata metadata = ImageMetadataReader.readMetadata(new ByteArrayInputStream(imageBytes));
        return new ExifMetadata(readGpsPoint(metadata), readCapturedAt(metadata));
    }

    public static Point createPoint(double lon, double lat) {
        Point p = geometryFactory.createPoint(new Coordinate(lon, lat)); // x=lon, y=lat
        p.setSRID(WGS84_SRID);
        return p;
    }

    private Point readGpsPoint(Metadata metadata) {
        GpsDirectory gpsDir = metadata.getFirstDirectoryOfType(GpsDirectory.class);
        if (gpsDir == null || gpsDir.getGeoLocation() == null) {
            return null;
        }

        return createPoint(gpsDir.getGeoLocation().getLongitude(), gpsDir.getGeoLocation().getLatitude());
    }

    private Instant readCapturedAt(Metadata metadata) {
        ExifSubIFDDirectory subIfd = metadata.getFirstDirectoryOfType(ExifSubIFDDirectory.class);
        if (subIfd == null) {
            return null;
        }

        Date capturedAt = subIfd.getDateOriginal();
        return capturedAt == null ? null : capturedAt.toInstant();
    }

    public record ExifMetadata(Point gpsPoint, Instant capturedAt) {
    }
}
