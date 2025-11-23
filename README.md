***

# Documentație Modul PWM Controlat prin SPI

Această documentație descrie arhitectura și funcționarea sistemului PWM (Pulse Width Modulation) configurabil, controlat printr-o interfață serială SPI. Sistemul este compus din 6 module Verilog interconectate.

### 1. Modulul Principal: `top.v`
Acesta este modulul de nivel superior (Top Level) care integrează toate sub-modulele și gestionează interconectarea semnalelor.

---

## Module Funcționale

### 2. Interfața SPI: `spi_bridge.v`

Modulul `spi_bridge.v` realizează adaptarea protocolului serial extern la magistrala internă paralelă, funcționând ca un slave sincronizat la ceasul sistemului. 

Deoarece perifericul operează într-un domeniu de ceas de frecvență ridicată (100MHz), semnalul extern `sclk` nu este utilizat direct ca ceas, ci este eșantionat printr-un detector de fronturi cu dublu registru (`sclk_d1`/`sclk_d2`) pentru a elimina metastabilitatea și problemele de clock domain crossing. 

Logica implementează modul SPI standard (CPOL=0, CPHA=0), deplasând datele de intrare (`mosi`) într-un registru de recepție pe frontul crescător al ceasului virtual și actualizând linia `miso` pe frontul descrescător. Un mecanism critic este generarea semnalului `byte_sync` la completarea fiecărui byte, moment în care registrul de transmisie este reîncărcat cu date noi (`data_out`) pentru a susține transferuri continue fără pauze. De asemenea, ieșirea `miso` este trecută în stare de înaltă impedanță atunci când semnalul `cs_n` este inactiv, permițând coexistența mai multor periferice pe aceeași magistrală.

### 3. Decodorul de Instrucțiuni: `instr_dcd.v`

Acest modul acționează ca unitate de control între interfața SPI și fișierul de registre, utilizând un automat cu stări finite (FSM) pentru a interpreta fluxul de date. Protocolul impune o structură de tranzacție pe doi octeți: faza de `SETUP`, în care primul byte este decodat pentru a extrage direcția transferului (Read/Write) și adresa țintă, urmată de faza `DATA`, unde are loc transferul efectiv al valorii. 

Logica de generare a semnalelor de control `read` și `write` este strict condiționată de starea automatului și de impulsul de sincronizare `byte_sync`, garantând că accesul la registre se face doar atunci când datele sunt stabile și complete. Adresarea include un mecanism de calcul care combină biții primiți pentru a mapa corect cererile externe către spațiul de adrese fizic al perifericului, asigurând o decuplare logică între protocolul de comunicație și structura internă a memoriei.

### 4. Fișierul de Regiștri: `regs.v`

Acest modul implementează interfața de control dintre procesor și nucleul PWM, utilizând o arhitectură accesibilă pe 8 biți. 

Deoarece registrele de configurare critică (PERIOD, COMPARE1, COMPARE2) sunt pe 16 biți, acestea sunt mapate pe câte două adrese consecutive (LSB și MSB) pentru a permite accesul prin magistrala de date îngustă. Logica este strict sincronă, utilizând un singur bloc `always` și decodificare prin `case` pentru a asigura stabilitatea semnalelor și eliminarea condițiilor de cursă. 

O funcționalitate specifică este implementată la adresa 0x07 (`COUNTER_RESET`), unde o operație de scriere declanșează un registru de deplasare intern ce generează un impuls de reset controlat, cu o durată fixă de două cicluri de ceas (self-clearing). Pentru protecția integrității datelor, scrierile în registrele read-only (ex. starea contorului) sunt ignorate, iar citirea adreselor neutilizate returnează implicit valoarea 0.

### 5. Contor Programabil: `counter.v`

Acest modul implementează nucleul de numărare bidirecțional (Up/Down), având la bază un mecanism de prescalare exponențială ce generează tick-uri de incrementare la intervale de $2^{prescale}$ cicluri de ceas. 

Pentru a susține divizorul maxim, se utilizează un contor intern pe 32 de biți, iar valoarea exponentului este limitată hardware la maximum 31 pentru a preveni comportamente nedefinite ale operației de deplasare. 

Arhitectura asigură determinismul temporizării prin resetarea automată a prescalerului la dezactivarea semnalului de enable și tratează prioritar resetul sincron. Logica de tranziție gestionează explicit modurile de numărare (crescător vs. descrescător) și include protecții împotriva erorilor aritmetice (overflow/underflow) sau a configurațiilor invalide (perioadă nulă), garantând funcționarea robustă a generatorului PWM în orice regim.

### 6. Generator PWM: `pwm_gen.v`
Generează semnalul `pwm_out` prin compararea valorii contorului (`count_val`) cu regiștrii `compare`.

Modulul `pwm_gen.v` este responsabil pentru sinteza formei de undă PWM, comparând în timp real valoarea curentă a contorului cu pragurile configurate (`compare1`, `compare2`) și perioada totală. 

Funcționalitatea este dictată de registrul de configurare `functions`, care selectează între modurile Aliniat (Stânga/Dreapta) și Nealiniat. În modul standard (Left-Aligned), ieșirea este activă cât timp contorul este sub pragul `compare1`, în timp ce modul Right-Aligned inversează logica, activând semnalul în ultima porțiune a perioadei (`period - compare1`). Modul Nealiniat (sau "window mode") oferă flexibilitate maximă, generând un impuls activ strict în intervalul dintre `compare1` și `compare2`, permițând astfel controlul precis atât al factorului de umplere, cât și al fazei semnalului în raport cu ciclul de numărare.

#### Moduri de Operare:

| Mod | Configurație | Logică Generare Semnal |
| :--- | :--- | :--- |
| **Left Aligned** | Aliniat + Stânga | Output `HIGH` când `count_val < compare1`. |
| **Right Aligned** | Aliniat + Dreapta | Output `HIGH` când `count_val >= (period - compare1)`. |
| **Unaligned** | Nealiniat | Output `HIGH` când `compare1 <= count_val < compare2`. |