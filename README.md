# A* – Flutter (Desktop + Klawiatura)
A* to prosta aplikacja napisana w języku Dart z wykorzystaniem frameworka Flutter. 
Prezentuje działanie algorytmu A* na siatce (gridzie) wraz z obsługą punktu startu, celu oraz opcjonalnego punktu pośredniego. 
Wersja jest przystosowana do uruchamiania na desktopie i obsługuje sterowanie z klawiatury.


# Funkcjonalności
Animowana wizualizacja algorytmu A*:
Znajduje najkrótszą ścieżkę od punktu startu do punktu docelowego.
Obsługa punktu pośredniego (waypoint):
Aplikacja może znaleźć drogę w dwóch etapach: start → punkt pośredni → cel.
Edytowanie siatki:
Ustawianie początku (Start) – czerwona kratka.
Ustawianie celu (Goal) – niebieska kratka.
Dodawanie punktu pośredniego (Waypoint) – fioletowa kratka.
Dodawanie i usuwanie przeszkód (Obstacle) – ciemne kratki.
Sterowanie z klawiatury:
Strzałki → przesuwanie kursora po siatce.
Spacja → kliknięcie w aktualną pozycję kursora (dodanie/usunięcie przeszkody lub zmiana punktu startu/celu/pośredniego zależnie od wybranego trybu).
Ładowanie gotowego layoutu siatki (plik assets/grid).
Reset stanu i ponowne uruchomienie algorytmu.

# Wymagania systemowe
Flutter w wersji co najmniej 3.0.0.
Instrukcje instalacji: Flutter - Instalacja
Środowisko obsługujące uruchamianie aplikacji Fluttera na desktopie (Windows / macOS / Linux).
Opcjonalnie: Emulator Android / iOS, jeśli chcesz przetestować aplikację na urządzeniach mobilnych.


# Obsługa aplikacji
Tryby edycji (na dole ekranu w postaci przycisków/ChoiceChip):
Start – klikając lub wciskając Spację w trybie Start, ustalasz punkt początkowy.
Cel (Goal) – ustalasz miejsce docelowe.
Pośredni (Waypoint) – opcjonalny punkt pomiędzy startem a celem.
Przeszkody (Obstacle) – klikanie/spacja w tym trybie dodaje (lub usuwa) przeszkody.

# Klawiatura:
Strzałki – poruszanie kursorem po siatce.
Spacja – wybór/ustawienie w danym trybie edycji (start, cel, waypoint lub obstacle).

# Dolny pasek przycisków:
Uruchom A* – rozpoczyna wyliczanie ścieżki (z animacją), uwzględniając punkt pośredni, jeśli jest ustawiony.
Stop – zatrzymuje animację.
Reset – ładuje ponownie siatkę z pliku assets/grid i resetuje stan.
