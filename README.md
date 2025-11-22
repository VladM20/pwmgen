***

# Documentație Modul PWM Controlat prin SPI

Această documentație descrie arhitectura și funcționarea sistemului PWM (Pulse Width Modulation) configurabil, controlat printr-o interfață serială SPI. Sistemul este compus din 6 module Verilog interconectate.

## Arhitectură Generală

### 1. Modulul Principal: `top.v`
Acesta este modulul de nivel superior (Top Level) care integrează toate sub-modulele și gestionează interconectarea semnalelor.

* **Rol:** Realizează legătura dintre pinii fizici ai FPGA-ului/ASIC-ului și logica internă.
* **Interfață:**
    * **System:** `clk`, `rst_n`
    * **SPI:** `sclk`, `cs_n`, `miso`, `mosi`
    * **Output:** `pwm_out`
* **Ierarhie:** Instanțiază `spi_bridge`, `instr_dcd`, `regs`, `counter` și `pwm_gen`.

---

## Module Funcționale

### 2. Interfața SPI: `spi_bridge.v`
Acest modul acționează ca un **Slave SPI**, convertind semnalele seriale externe în date paralele pe 8 biți pentru uz intern.



* **Sincronizare:** Utilizează un mecanism de eșantionare dublă (`sclk_d1`, `sclk_d2`) pentru a detecta flancurile semnalului de ceas `sclk` și a le sincroniza cu ceasul sistemului (`clk`).
* **Recepție (MOSI):** Datele sunt citite pe flancul **crescător** (rising edge) al `sclk` și stocate în registrul de deplasare `shift_reg_rx`.
* **Transmisie (MISO):** Datele sunt schimbate pe linia de ieșire pe flancul **descrescător** (falling edge) al `sclk` din `shift_reg_tx`.
* **Handshake:** Emite semnalul `byte_sync` (puls de un ciclu) atunci când un octet complet a fost transferat, validând datele pe `data_in`.

### 3. Decodorul de Instrucțiuni: `instr_dcd.v`
Interpretează pachetele de date primite și gestionează mașina de stări (FSM) pentru accesul la regiștri.

* **Protocol:** Comunicarea se realizează în tranzacții de 2 octeți:
    1.  **Byte 1 (Comandă & Adresă):**
        * Bit [7]: Operație (0 = Read, 1 = Write).
        * Biții [5:0]: Adresa registrului țintă.
    2.  **Byte 2 (Date):**
        * Write: Valoarea efectivă de scris.
        * Read: Octet "dummy" (ignorat la recepție, folosit pentru a genera ceas pentru MISO).
* **Control:** Activează semnalele `read` sau `write` către fișierul de regiștri doar când FSM-ul este în starea `STATE_DATA` și semnalul `byte_sync` este activ.

### 4. Fișierul de Regiștri: `regs.v`
Stochează configurația sistemului și face legătura între parametrii software și blocurile hardware (`counter`, `pwm_gen`).

#### Harta Memoriei (Register Map)

| Adresă | Nume Registru | Descriere | Acces |
| :--- | :--- | :--- | :--- |
| `0x00-0x01` | `period` | Perioada contorului (16 biți) | R/W |
| `0x02` | `en` | Activare contor (Bit 0) | R/W |
| `0x03-0x04` | `compare1` | Prag comparator 1 (16 biți) | R/W |
| `0x05-0x06` | `compare2` | Prag comparator 2 (16 biți) | R/W |
| `0x07` | `count_reset` | Resetare software contor (Declanșează puls intern) | **W** |
| `0x08-0x09` | `counter_val` | Valoarea curentă a contorului (16 biți) | **R** |
| `0x0A` | `prescale` | Divizor frecvență (Exponent) | R/W |
| `0x0B` | `upnotdown` | Direcție: 1=Up, 0=Down | R/W |
| `0x0C` | `pwm_en` | Activare ieșire PWM | R/W |
| `0x0D` | `functions` | Configurare mod PWM (Biții 1:0) | R/W |

### 5. Contor Programabil: `counter.v`
Un contor flexibil pe 16 biți care generează baza de timp.

* **Prescaler:** Funcționează exponențial. Perioada unui "tick" de contor este calculată astfel:
    $$T_{tick} = T_{clk} \times 2^{prescale}$$
    *(Ex: prescale=0 -> 1 ciclu, prescale=2 -> 4 cicluri).*
* **Direcție:** Controlată de `upnotdown`.
    * **Up:** Numără 0 $\rightarrow$ `period` $\rightarrow$ 0.
    * **Down:** Numără `period` $\rightarrow$ 0 $\rightarrow$ `period`.
* **Priorități:** Resetul sincron (`count_reset`) are prioritate maximă, urmat de semnalul de enable (`en`).

### 6. Generator PWM: `pwm_gen.v`
Generează semnalul `pwm_out` prin compararea valorii contorului (`count_val`) cu regiștrii `compare`.



#### Configurare prin registrul `functions`:
Registrul `functions` determină modul de formare a undei:

* **Bit 1 (Mode):** `0` = Aliniat, `1` = Nealiniat.
* **Bit 0 (Align):** `0` = Stânga, `1` = Dreapta (valid doar în mod Aliniat).

#### Moduri de Operare:

| Mod | Configurație | Logică Generare Semnal |
| :--- | :--- | :--- |
| **Left Aligned** | Aliniat + Stânga | Output `HIGH` când `count_val < compare1`. |
| **Right Aligned** | Aliniat + Dreapta | Output `HIGH` când `count_val >= (period - compare1)`. |
| **Unaligned** | Nealiniat | Output `HIGH` când `compare1 <= count_val < compare2`. |