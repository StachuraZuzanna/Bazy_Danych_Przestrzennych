-- create extension postgis_raster;
-- pg_restore -U postgres -d cw6 -h localhost -p 5433 -W -v "C:\Users\Zuzia\Desktop\BazyDanychPrzestrzennych\ćwiczenia6\postgis_raster.backup"
-- ALTER SCHEMA schema_name RENAME TO Stachura;
-- raster2pgsql -s 3763 -N -32767 -t 100x100 -I -C -M -d "C:\Users\Zuzia\Desktop\BazyDanychPrzestrzennych\ćwiczenia6\srtm_1arc_v3.tif" rasters.dem | psql -d cw6 -h localhost -U postgres -p 5433
-- raster2pgsql -s 3763 -N -32767 -t 128x128 -I -C -M -d C:\Users\Zuzia\Desktop\BazyDanychPrzestrzennych\cwiczenia6\Landsat8_L1TP_RGBN.tif rasters.landsat8 | psql -d cw6 -h localhost -U postgres -p 5433

--************************************************************************************************************************************************

-- Tworzenie rastrów z istniejących rastrów i interakcja z wektorami

------------------------------------- Przykład 1 - ST_Intersects
-- Przecięcie rastra z wektorem.
--                                   boolean ST_Intersects( raster rastA , raster rastB );
-- *****	Zwraca wartość true, jeśli raster rastA przecina przestrzennie raster rastB. Jeżeli nie podano numeru pasma (lub ustawiono go na NULL), 
-- ***** 	w teście uwzględniana jest tylko wypukła część rastra. Jeśli podany jest numer pasma, w teście brane są pod uwagę tylko piksele 
-- ***** 	posiadające wartość (nie NODATA).

CREATE TABLE stachura.intersects AS 
SELECT a.rast, b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b 
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto';

-- 1. dodanie serial primary key
alter table stachura.intersects
add column rid SERIAL PRIMARY KEY;

-- 2. utworzenie indeksu przestrzennego:
CREATE INDEX idx_intersects_rast_gist ON stachura.intersects
USING gist (ST_ConvexHull(rast));

-- 3. dodanie raster constraints:
-- schema::name table_name::name raster_column::name
SELECT AddRasterConstraints('stachura'::name, 
'intersects'::name,'rast'::name);

------------------------------------------------ Przykład 2 - ST_Clip
-- Obcinanie rastra na podstawie wektora.
--						 raster ST_Clip(raster rast, integer[] nband, geometry geom, double precision[] nodataval=NULL, boolean crop=TRUE);
-- ***			Zwraca raster obcięty przez geometrię wejściową geom. Jeśli nie określono indeksu pasma, przetwarzane są wszystkie pasma.
CREATE TABLE stachura.clip AS 
SELECT ST_Clip(a.rast, b.geom, true), b.municipality 
FROM rasters.dem AS a, vectors.porto_parishes AS b 
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality like 'PORTO';

------------------------------------------------- Przykład 3 - ST_Union
-- Połączenie wielu kafelków w jeden raster.
--                          raster ST_Union(setof raster rast);
-- *****		Zwraca połączenie zestawu płytek rastrowych w pojedynczy raster składający się z co najmniej jednego pasma. 
-- *****		Zasięg powstałego rastra jest zasięgiem całego zbioru.
CREATE TABLE stachura.union AS 
SELECT ST_Union(ST_Clip(a.rast, b.geom, true))
FROM rasters.dem AS a, vectors.porto_parishes AS b 
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast);

-- Oprócz powyższego przykładu, st_union pozwala również na operacje na nakładających się rastrach
-- opartych na danej funkcji agregującej, a mianowicie FIRST LAST SUM COUNT MEAN lub RANGE. Na
-- przykład, jeśli mamy wiele rastrów z danymi o opadach atmosferycznych i potrzebujemy średniej
-- wartości, możemy użyć st_union lub map_algebra. 

--************************************************************************************************************************************************
-- Tworzenie rastrów z wektorów (rastrowanie)
-- Poniższe przykłady pokazują rastrowanie wektoru.

----------------------------------- Przykład 1 - ST_AsRaster
-- Przykład pokazuje użycie funkcji ST_AsRaster w celu rastrowania tabeli z parafiami o takiej samej
-- charakterystyce przestrzennej tj.: wielkość piksela, zakresy itp.
-- *****	 Konwertuje geometrię PostGIS na raster PostGIS. Wiele wariantów oferuje trzy grupy możliwości ustawienia wyrównania
-- *****	i rozmiaru pikseli powstałego rastra.

CREATE TABLE stachura.porto_parishes AS
WITH r AS (
	SELECT rast FROM rasters.dem
	LIMIT 1
)
SELECT ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

------------------------------------------------- Przykład 2 - ST_Union
-- Wynikowy raster z poprzedniego zadania to jedna parafia na rekord, na wiersz tabeli.
-- Użyj QGIS lub ArcGIS do wizualizacji wyników.
-- Drugi przykład łączy rekordy z poprzedniego przykładu przy użyciu funkcji ST_UNION w pojedynczy raster.
DROP TABLE stachura.porto_parishes; --> drop table porto_parishes first

CREATE TABLE stachura.porto_parishes AS
WITH r AS (
	SELECT rast FROM rasters.dem
	LIMIT 1
)
SELECT st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';


------------------------------------------------------ Przykład 3 - ST_Tile
-- Po uzyskaniu pojedynczego rastra można generować kafelki za pomocą funkcji ST_Tile.
-- *****		Zwraca zestaw rastrów powstały w wyniku podziału rastra wejściowego na podstawie żądanych wymiarów rastrów wyjściowych.


DROP TABLE stachura.porto_parishes; --> drop table porto_parishes first
CREATE TABLE stachura.porto_parishes AS
WITH r AS (
	SELECT rast FROM rasters.dem 
	LIMIT 1 
)
SELECT st_tile(st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)),128,128,true,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';
--************************************************************************************************************************************************


-- Konwertowanie rastrów na wektory (wektoryzowanie)
-- Poniższe przykłady użycia funkcji ST_Intersection i ST_DumpAsPolygons pokazują konwersję rasterów na wektory. 

-------------------------------------------  Przykład 1 - ST_Intersection
-- Funkcja St_Intersection jest podobna do ST_Clip. ST_Clip zwraca raster, a ST_Intersection zwraca
-- zestaw par wartości geometria-piksel, ponieważ ta funkcja przekształca raster w wektor przed
-- rzeczywistym „klipem”. Zazwyczaj ST_Intersection jest wolniejsze od ST_Clip więc zasadnym jest
-- przeprowadzenie operacji ST_Clip na rastrze przed wykonaniem funkcji ST_Intersection.
-- Zwraca zestaw wartości geomval
create table stachura.intersection as
SELECT a.rid,(ST_Intersection(b.geom,a.rast)).geom,(ST_Intersection(b.geom,a.rast)).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);


-----------------------------------------  Przykład 2 - ST_DumpAsPolygons
-- ST_DumpAsPolygons konwertuje rastry w wektory (poligony).
-- Zwraca zestaw wartości geomval

CREATE TABLE stachura.dumppolygons AS
SELECT a.rid,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).geom,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

--************************************************************************************************************************************************

--Analiza rastrów

-------------------------------------------- Przykład 1 - ST_Band
-- Funkcja ST_Band służy do wyodrębniania pasm z rastra
-- wraca jedno lub więcej pasm istniejącego rastra jako nowy raster. Przydatne do budowania nowych rastrów z istniejących 
-- rastrów lub eksportu tylko wybranych pasm rastra lub zmiany kolejności pasm w rastrze.
CREATE TABLE stachura.landsat_nir AS
SELECT rid, ST_Band(rast,4) AS rast
FROM rasters.landsat8;

----------------------------------------------- Przykład 2 - ST_Clip
-- ST_Clip może być użyty do wycięcia rastra z innego rastra. Poniższy przykład wycina jedną parafię z
-- tabeli vectors.porto_parishes. Wynik będzie potrzebny do wykonania kolejnych przykładów.
CREATE TABLE stachura.paranhos_dem AS
SELECT a.rid,ST_Clip(a.rast, b.geom,true) as rast
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

------------------------------------------  Przykład 3 - ST_Slope
-- Poniższy przykład użycia funkcji ST_Slope wygeneruje nachylenie przy użyciu poprzednio
-- wygenerowanej tabeli (wzniesienie).
--********	  Zwraca nachylenie (domyślnie w stopniach) pasma rastrowego elewacji. Wykorzystuje algebrę mapy
--******** 	  i stosuje równanie nachylenia do sąsiednich pikseli. 
--*******	  unitswskazuje jednostki nachylenia. Możliwe wartości to: RADIAN, STOPNIE (domyślnie), PROCENT.
CREATE TABLE stachura.paranhos_slope AS
SELECT a.rid,ST_Slope(a.rast,1,'32BF','PERCENTAGE') as rast
FROM stachura.paranhos_dem AS a;


------------------------------------------ Przykład 4 - ST_Reclass
-- Aby zreklasyfikować raster należy użyć funkcji ST_Reclass.
--******	 Tworzy nowy raster utworzony poprzez zastosowanie prawidłowej operacji algebraicznej PostgreSQL zdefiniowanej
--******	 przez reclassexprraster wejściowy ( rast). Jeśli nie bandokreślono, przyjmuje się zakres 1. Nowy raster będzie
--******	 miał taką samą georeferencję, szerokość i wysokość jak oryginalny raster.
CREATE TABLE stachura.paranhos_slope_reclass AS
SELECT a.rid,ST_Reclass(a.rast,1,']0-15]:1, (15-30]:2, (30-9999:3','32BF',0)
FROM stachura.paranhos_slope AS a;

--------------------------------------------- Przykład 5 - ST_SummaryStats
-- Aby obliczyć statystyki rastra można użyć funkcji ST_SummaryStats. Poniższy przykład wygeneruje statystyki dla kafelka.
--******	 Zwraca statystyki podsumowujące składające się z liczby, sumy, średniej, odchylenie standardowe, min, max dla danego pasma
--******	 rastrowego lub pokrycia rastra. Jeśli nie określono żadnego pasma, nbanddomyślnie jest to 1.
SELECT st_summarystats(a.rast) AS stats
FROM stachura.paranhos_dem AS a;


---------------------------------------- Przykład 6 - ST_SummaryStats oraz Union
-- Przy użyciu UNION można wygenerować jedną statystykę wybranego rastra.
SELECT st_summarystats(ST_Union(a.rast))
FROM stachura.paranhos_dem AS a;


---------------------------------------------- Przykład 7 - ST_SummaryStats z lepszą kontrolą złożonego typu danych
WITH t AS (
	SELECT st_summarystats(ST_Union(a.rast)) AS stats
	FROM stachura.paranhos_dem AS a
)
SELECT (stats).min,(stats).max,(stats).mean FROM t;


-------------------------------------------------Przykład 8 - ST_SummaryStats w połączeniu z GROUP BY
-- Aby wyświetlić statystykę dla każdego poligonu "parish" można użyć polecenia GROUP BY
WITH t AS (
	SELECT b.parish AS parish, st_summarystats(ST_Union(ST_Clip(a.rast,b.geom,true))) AS stats
	FROM rasters.dem AS a, vectors.porto_parishes AS b
	WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
	group by b.parish
)
SELECT parish,(stats).min,(stats).max,(stats).mean FROM t;

---------------------------------------------------- Przykład 9 - ST_Value
-- Funkcja ST_Value pozwala wyodrębnić wartość piksela z punktu lub zestawu punktów.
-- Poniższy przykład wyodrębnia punkty znajdujące się w tabeli vectors.places.
-- Ponieważ geometria punktów jest wielopunktowa, a funkcja ST_Value wymaga geometrii
-- jednopunktowej, należy przekonwertować geometrię wielopunktową na geometrię jednopunktową
-- za pomocą funkcji (ST_Dump(b.geom)).geom.
SELECT b.name,st_value(a.rast,(ST_Dump(b.geom)).geom)
FROM rasters.dem a, vectors.places AS b
WHERE ST_Intersects(a.rast,b.geom)
ORDER BY b.name;



-- Topographic Position Index (TPI)
-- TPI porównuje wysokość każdej komórki w DEM ze średnią wysokością określonego sąsiedztwa wokół tej komórki.
-- Wartości dodatnie reprezentują lokalizacje, które są wyższe niż średnia ich otoczenia, zgodnie z definicją sąsiedztwa (grzbietów). 
-- Wartości ujemne reprezentują lokalizacje, które są niższe niż ich otoczenie (doliny). 
-- Wartości TPI bliskie zeru to albo płaskie obszary (gdzie nachylenie jest bliskie zeru), albo obszary o stałym nachyleniu. 


------------------------------------ Przykład 10 - ST_TPI
-- Funkcja ST_Value pozwala na utworzenie mapy TPI z DEM wysokości. Obecna wersja PostGIS może
-- obliczyć TPI jednego piksela za pomocą sąsiedztwa wokół tylko jednej komórki. Poniższy przykład
-- pokazuje jak obliczyć TPI przy użyciu tabeli rasters.dem jako danych wejściowych. Tabela nazywa się
-- TPI30 ponieważ ma rozdzielczość 30 metrów i TPI używa tylko jednej komórki sąsiedztwa do obliczeń.
-- Tabela wyjściowa z wynikiem zapytania zostanie stworzona w schemacie schema_name, jest więc możliwa jej wizualizacja w QGIS.
create table stachura.tpi30 as
select ST_TPI(a.rast,1) as rast
from rasters.dem a;

-- Poniższa kwerenda utworzy indeks przestrzenny:
CREATE INDEX idx_tpi30_rast_gist ON stachura.tpi30
USING gist (ST_ConvexHull(rast));

-- Dodanie constraintów:
SELECT AddRasterConstraints('stachura'::name,
'tpi30'::name,'rast'::name);
-- ***************************************************************************************************
-- Algebra map
-- Istnieją dwa sposoby korzystania z algebry map w PostGIS. Jednym z nich jest użycie wyrażenia, a
-- drugim użycie funkcji zwrotnej. Poniższe przykłady pokazują jak stosując obie techniki utworzyć
-- wartości NDVI na podstawie obrazu Landsat8.
-- Wzór na NDVI:
-- NDVI=(NIR-Red)/(NIR+Red)

-------------------------------------------------------- Przykład 1 - Wyrażenie Algebry Map
CREATE TABLE stachura.porto_ndvi AS
WITH r AS (
	SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
	FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
	WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
r.rid,ST_MapAlgebra(r.rast, 1,r.rast, 4,'([rast2.val] - [rast1.val]) / ([rast2.val] +[rast1.val])::float','32BF') AS rast
FROM r;

-- Poniższe zapytanie utworzy indeks przestrzenny na wcześniej stworzonej tabeli:
CREATE INDEX idx_porto_ndvi_rast_gist ON stachura.porto_ndvi
USING gist (ST_ConvexHull(rast));

-- Dodanie constraintów:
SELECT AddRasterConstraints('stachura'::name,'porto_ndvi'::name,'rast'::name);
-- Możliwe jest użycie algebry map na wielu rastrach i/lub wielu pasmach,
-- służy do tego rastbandargset. 

--------------------------------------------------------- Przykład 2 – Funkcja zwrotna
-- W pierwszym kroku należy utworzyć funkcję, które będzie wywołana później:
create or replace function stachura.ndvi(
	value double precision [] [] [],
	pos integer [][],
	VARIADIC userargs text []
)
RETURNS double precision AS
$$
BEGIN
--RAISE NOTICE 'Pixel Value: %', value [1][1][1];-->For debugpurposes
RETURN (value [2][1][1] - value [1][1][1])/(value [2][1][1]+value
[1][1][1]); --> NDVI calculation!
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE COST 1000;

-- W kwerendzie algebry map należy można wywołać zdefiniowaną wcześniej funkcję:
CREATE TABLE stachura.porto_ndvi2 AS
WITH r AS (
	SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
	FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
	WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
r.rid,ST_MapAlgebra(r.rast, ARRAY[1,4],
					'stachura.ndvi(double precision[],integer[],text[])'::regprocedure, --> This is the function!
					'32BF'::text
) AS rast
FROM r;

-- Dodanie indeksu przestrzennego:
CREATE INDEX idx_porto_ndvi2_rast_gist ON stachura.porto_ndvi2
USING gist (ST_ConvexHull(rast));

-- Dodanie constraintów:
SELECT AddRasterConstraints('stachura'::name,
'porto_ndvi2'::name,'rast'::name);

