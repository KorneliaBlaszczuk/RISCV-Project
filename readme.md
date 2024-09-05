# Projekt ARKO - RISC V

## Find Marker no. 3

## Kornelia Błaszczuk, 331361

## Działanie skryptu
<br>
<strong>Etap 1</strong><br>
Na początku znajdujemy czarny piksel. Mierzymy kolejno: jego wysokość, grubość ramienia wysokości, szerokość, grubość ramienia szerokości. Następnie patrzymy, czy wysokość jest równa szerokości oraz czy szerokość markera jest różna od grubości ramienia wysokości (żebyśmy nie wzieli kwadratu za nasz marker).
<br>
<strong>Etap 2</strong><br>
Sprawdzamy, czy każdy piksel markera jest w środku czarny. Program zaczyna od punktu połączenia ramion i iterując kolejno po kolumnach markera, mieszy dane wysokości. Dzieje się to w dwóch etapach - wysokość markera oraz grubość ramienia szerokości. Na tym etapie od razu sprawdzamy granice markera nad wysokością oraz szerokością (czy nie ma pikselów odstających).
<br>
<strong>Etap 3</strong><br>
Przechodzimy kolejne przez granice markera. Zaczynamy od punktu za marker, obniżamy go o jeden rząd. Sprawdzamy, czy wszystkie piksele przy szerokości nie są czarne. Dodatkowo sprawdzamy te skrajne pola. To samo robimy z granicamy przy wysokości. Ostatnią granicą jest ta pod szerokością.
W przypadku trzech granic (1, 3, 4) możemy ich nie wykonać, jeśli marker znajduje się na skrajnej pozycji na obrazie.

## Testy

Zostało przeprowadzonych kilkanaście testów, które sprawdziły poprawność algorytmu. Wszystkie zachowały się zgodnie z założeniami. Zostały przetestowane sytuacje typowe, jak i skrajne.

## Uruchomienie programy

RARS, plik z programem wyszukującym maeker nr. 3 oraz plik bmp muszą być w tym samym folderze. Zalecam zrobienie osobne na pulpitcie w tym celu.
