package com.ray.farm.mapping;

import com.ray.farm.mapping.model.ItemGeoRecord;
import com.ray.farm.mapping.service.ExifReaderService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest(properties = {
        "app.storage.photoDir =./data/photos"
})
@ActiveProfiles("test")
class FarmMappingApplicationTests {

    @Autowired
    private final ExifReaderService exifReaderService = null;


    @Test
    void extractsGpsFromPhoto() throws Exception {

        ItemGeoRecord record = exifReaderService.getExifData("tree1-with-location-data.jpg");

        double lat = record.getLocation().getCoordinate().getY();
        double lon = record.getLocation().getCoordinate().getX();

        assertEquals(40.2004238, lat, 1e-7);
        assertEquals(-7.6364395, lon, 1e-7);
    }

}
