package com.ray.farm.mapping.model;

public enum TreeSpecies {

    PINE("PineIcon"), OAK("OakIcon"), PLANE("PlaneIcon"), PRICKLY_PEAR_CACTUS("PricklyPearCactusIcon"), EUCALYPTUS("EculapytusIcon");

    private final String iconKey;

    TreeSpecies(String iconKey) {
        this.iconKey = iconKey;
    }

    public String iconKey() {
        return iconKey;
    }
}
