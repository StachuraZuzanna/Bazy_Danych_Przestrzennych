
--2.create database pusta;
--3.  CREATE EXTENSION postgis;
--4. 
create table buildings (
	id integer primary key,
	geometry geometry(Polygon,4326),
	name varchar(50)
);

create table roads (
	id integer primary key,
	geometry geometry(LineString,4326),
	name varchar(50)
);

create table poi (
	id integer primary key,
	geometry geometry(Point,4326),
	name varchar(50)
);

-- -- Punkty wierzchołka są oddzielone przecinkami, 
-- -- a końce wielokąta są łączone poprzez powtórzenie pierwszego punktu (x1 y1) na końcu.

-- 5.
insert into buildings (id,geometry, name)
values
    (1,'POLYGON((8 4, 10.5 4, 10.5 1.5, 8 1.5, 8 4))','BuildingA'),
    (2,'POLYGON((4 7, 6 7, 6 5, 4 5, 4 7))','BuildingB'),
	(3,'POLYGON((3 8, 5 8, 5 6, 3 6, 3 8))','BuildingC'),
	(4,'POLYGON((9 9, 10 9, 10 8, 9 8, 9 9))','BuildingD'),
	(5,'POLYGON((1 2, 2 2, 2 1, 1 1, 1 2))','BuildingE')
;

insert into roads (id,geometry, name)
values
    (1,'LINESTRING(0 4.5,12 4.5)','RoadX'),
	(2,'LINESTRING(7.5 0,7.5 10.5)','RoadY')
;

insert into poi (id,geometry, name)
values
    (1,'POINT(1 3.5)','G'),
	(2,'POINT(5.5 1.5)','H'),
	(3,'POINT(9.5 6)','I'),
	(4,'POINT(6.5 6)','J'),
	(5,'POINT(6 9.5)','K')
;

select * from roads
union all
select * from buildings
union all
select * from poi;

-- 6. Na bazie przygotowanych tabel wykonaj poniższe polecenia:
-- a. Wyznacz całkowitą długość dróg w analizowanym mieście. 
select sum(ST_Length(geometry)) 
as total_length_roads
from roads;

-- b. Wypisz geometrię (WKT), pole powierzchni oraz obwód poligonu reprezentującego 
-- budynek o nazwie BuildingA. 
select
    ST_AsText(geometry) as geometry_wkt,
    ST_Area(geometry) AS pole,
    ST_Perimeter(geometry) AS obwod
from buildings
where name = 'BuildingA';

-- c. Wypisz nazwy i pola powierzchni wszystkich poligonów w warstwie budynki. Wyniki 
-- posortuj alfabetycznie. 
select
    name,
    ST_Area(geometry) as pole
from buildings
where ST_GeometryType(geometry) = 'ST_Polygon'
order by name;

-- d. Wypisz nazwy i obwody 2 budynków o największej powierzchni. 
select
    name,
    ST_Perimeter(geometry) as obwod
from buildings
order by ST_Area(geometry) desc
limit 2;

-- e. Wyznacz najkrótszą odległość między budynkiem BuildingC a punktem K. 
select
    ST_Distance(buildings.geometry, poi.geometry) as shortest_distance
from buildings
join poi on  
	buildings.name = 'BuildingC' and poi.name = 'K';

--lub
select
    ST_Distance(buildings.geometry, poi.geometry) as shortest_distance
from buildings
cross join poi 
where buildings.name = 'BuildingC' and poi.name = 'K';
-- cross join pozwala na utworzenie wszystkich możliwych kombinacji między tabelami "buildings" 
-- i "poi," co oznacza, że każdy budynek zostanie zestawiony z każdym punktem.

-- f. Wypisz pole powierzchni tej części budynku BuildingC, która znajduje się w odległości 
-- większej niż 0.5 od budynku BuildingB. 

SELECT
    ST_Area(ST_Difference(BuildingC.geometry, ST_Buffer(BuildingB.geometry, 0.5))) AS area
FROM buildings AS BuildingC, buildings AS BuildingB
WHERE BuildingC.name = 'BuildingC' AND BuildingB.name = 'BuildingB';
-- * ST_Buffer(BuildingB.geometry, 0.5) tworzy bufor o promieniu 0.5 jednostki wokół budynku "BuildingB."
-- * ST_Difference(BuildingC.geometry, ST_Buffer(BuildingB.geometry, 0.5)) oblicza różnicę między geometrią budynku "BuildingC" a buforem wokół budynku "BuildingB." 


-- g. Wybierz te budynki, których centroid (ST_Centroid) znajduje się powyżej drogi  o nazwie RoadX.
SELECT b.*
FROM buildings b
WHERE ST_Y(ST_Centroid(b.geometry)) > (SELECT ST_Y(ST_Centroid(geometry)) FROM roads WHERE name = 'RoadX');
-- * ST_Y(ST_Centroid(b.geometry)) pobiera współrzędną Y tego centroidu.


--h.Oblicz pole powierzchni tych części budynku BuildingC i poligonu 
-- o współrzędnych (4 7, 6 7, 6 8, 4 8, 4 7), które nie są wspólne dla tych dwóch obiektów.

WITH buildingC AS (
    SELECT geometry
    FROM buildings
    WHERE name = 'BuildingC'
),
polygon AS (
    SELECT ST_SetSRID('POLYGON((4 7, 6 7, 6 8, 4 8, 4 7))'::geometry, 4326) AS geometry
)

SELECT 
    ST_Area(ST_Difference(buildingC.geometry, polygon.geometry)) + ST_Area(ST_Difference(polygon.geometry, buildingC.geometry)) AS pole
FROM buildingC, polygon 
WHERE ST_Intersects(buildingC.geometry, polygon.geometry);





--zrzucić do notatnika

