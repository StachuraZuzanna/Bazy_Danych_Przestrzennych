-- create extension postgis

-- 1. Utwórz tabelę obiekty. W tabeli umieść nazwy i geometrie obiektów przedstawionych poniżej. 
-- Układ odniesienia ustal jako niezdefiniowany.

-- 1.
CREATE TABLE obiekty (id SERIAL PRIMARY KEY, nazwa varchar(20), geom geometry);

-- a)
INSERT INTO obiekty(nazwa, geom) 
VALUES('obiekt1',
	   ST_COLLECT(Array['LINESTRING(0 1, 1 1)',
						'CIRCULARSTRING(1 1, 2 0, 3 1)',
						'CIRCULARSTRING(3 1, 4 2, 5 1)',
						'LINESTRING(5 1, 6 1)']
				 ));


-- b)
INSERT INTO obiekty(nazwa, geom) 
VALUES('obiekt2',
	   ST_BuildArea(ST_Collect(Array['LINESTRING(10 2, 10 6, 14 6)',
									 'CIRCULARSTRING(14 6, 16 4, 14 2)',
									 'CIRCULARSTRING(14 2, 12 0, 10 2)',
									 'CIRCULARSTRING(11 2, 13 2, 11 2)']
							  )));


-- c)
INSERT INTO obiekty(nazwa, geom)
VALUES('obiekt3',
	   ST_GeomFromText('POLYGON((10 17, 12 13, 7 15,10 17))',0));  -- 0 ponieważ układ odniesienia niezdefiniowany

-- d)
INSERT INTO obiekty(nazwa, geom)
VALUES('obiekt4',
	   ST_GeomFromText('LINESTRING(20 20, 25 25, 27 24, 25 22, 26 21, 22 19, 20.5 19.5)',0));


-- e) 
INSERT INTO obiekty(nazwa, geom)
VALUES('obiekt5',
	   ST_GeomFromText('MULTIPOINT((30 30 59),(38 32 234))',0));


-- f) 
INSERT INTO obiekty(nazwa, geom)
VALUES('obiekt6',
	   ST_GeomFromText('GEOMETRYCOLLECTION( LINESTRING(1 1, 3 2) , POINT(4 2))',0));

---------------------------------------------------------- Zad 2

-- 2. Wyznacz pole powierzchni bufora o wielkości 5 jednostek, który został utworzony wokół 
-- najkrótszej linii łączącej obiekt 3 i 4.

SELECT ST_Area(ST_Buffer(ST_ShortestLine(ob3.geom, ob4.geom), 5)) AS pole
FROM obiekty ob3, obiekty ob4
WHERE ob3.nazwa = 'obiekt3' AND ob4.nazwa = 'obiekt4';

-- 3. Zamień obiekt4 na poligon. Jaki warunek musi być spełniony, aby można było wykonać to 
-- zadanie? Zapewnij te warunki.
UPDATE obiekty
SET geom = ST_MakePolygon(ST_AddPoint(geom, ST_StartPoint(geom)))
WHERE nazwa = 'obiekt4'
  AND NOT ST_IsClosed(geom);
  
--   UPDATE obiekty SET geom = ST_MakePolygon(ST_AddPoint(geom, 'POINT(20 20)')) WHERE nazwa = 'obiekt4';

-- 4. W tabeli obiekty, jako obiekt7 zapisz obiekt złożony z obiektu 3 i obiektu 4.







