import * as L from "leaflet";
import "leaflet/dist/leaflet.css";

type Observation = {
    id: number;
    lat: number;
    lon: number;
    iconKey?: string;
    label?: string;
};

const map = L.map("map");

const minX = -851043.9790;
const maxX = -850541.3878;
const minY = 4893580.2088;
const maxY = 4894366.0692;

// EPSG:3857 meters -> LatLng
const southWest = (L.Projection as any).SphericalMercator.unproject(L.point(minX, minY));
const northEast = (L.Projection as any).SphericalMercator.unproject(L.point(maxX, maxY));
const bounds = L.latLngBounds(southWest, northEast);

// Fit map to your ortho and prevent panning away
map.fitBounds(bounds);
map.setMaxBounds(bounds);
(map as any).options.maxBoundsViscosity = 1.0;

// Tiles served by Spring Boot
L.tileLayer("/tiles/{z}/{x}/{y}.png", {
    minZoom: 14,
    maxZoom: 22,
    noWrap: true
}).addTo(map);

map.setView([40.2000, -7.5000], 18);

function iconFor(iconKey: string) {
    return L.icon({
        iconUrl: `/icons/${iconKey}.png`,
        iconSize: [24, 24],
        iconAnchor: [12, 12]
    });
}

let editMode = false;
const markers: L.Marker[] = [];

const editToggleBtn = document.getElementById("editToggle") as HTMLButtonElement;
editToggleBtn.addEventListener("click", () => {
    editMode = !editMode;
    editToggleBtn.textContent = `Edit mode: ${editMode ? "ON" : "OFF"}`;

    for (const m of markers) {
        if (editMode) m.dragging?.enable();
        else m.dragging?.disable();
    }
});

async function updateLocation(id: number, lat: number, lon: number) {
    const res = await fetch(`/api/observations/${id}/location`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ lat, lon })
    });
    if (!res.ok) throw new Error(`PATCH failed: ${res.status}`);
}

async function loadObservations() {
    const res = await fetch("/api/observations");
    const data: Observation[] = await res.json();

    for (const o of data) {
        const marker = L.marker([o.lat, o.lon], {
            icon: iconFor(o.iconKey ?? "unknown"),
            draggable: editMode
        })
            .addTo(map)
            .bindPopup(o.label ?? (o.iconKey ?? "unknown"));

        if (!editMode) marker.dragging?.disable();

        let last = { lat: o.lat, lon: o.lon };

        marker.on("dragend", async (e) => {
            if (!editMode) return;

            const ll = (e.target as L.Marker).getLatLng();
            const newLat = ll.lat;
            const newLon = ll.lng;

            try {
                await updateLocation(o.id, newLat, newLon);
                last = { lat: newLat, lon: newLon };
            } catch (err) {
                console.error(err);
                (e.target as L.Marker).setLatLng([last.lat, last.lon]);
                alert(`Failed to update location for id=${o.id}`);
            }
        });

        markers.push(marker);
    }
}

loadObservations().catch(console.error);
