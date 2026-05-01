# SmartNIC_Packet_Filter

High-throughput hardware firewall and packet processor designed for real-time Ethernet traffic filtering. This project implements a modular, pipelined architecture, offloading critical networking tasks from the CPU to hardware logic.

---

## 🚀 Key Features

*   **Pipelined AXI-Stream Data Path:** High-performance processing using **AXI-Stream** interfaces to ensure seamless data flow between modules
*   **Multi-Stage Packet Parsing:** Hardware-based parser designed to extract Ethernet and IPv4 headers "on-the-fly" using a robust **FSM**.
*   **Hardware-Based Filtering:** Implements a malicious IP blacklist using an **XOR-hash table** lookup logic, integrated with True Dual-Port **BRAM** for real-time decision making.
*   **Integrity Verification:** Dedicated **CRC32** engine that validates packet integrity in parallel with the filtering process.
*   **Clock Domain Crossing (CDC):** Managed via **Asynchronous FIFOs** with Gray code synchronization, enabling reliable data transfer between clock domains.

## 🏗️ System Architecture

The design is partitioned into specialized RTL modules:
*   **`asyn_fifo.v`**: Handles clock domain transitions and prevents metastability[cite: 1].
*   **`parser.v`**: Identifies IPv4 packets and extracts Source/Destination IP addresses.
*   **`CRC.v`**: Computes and verifies the 32-bit Frame Check Sequence (FCS).
*   **`Firewall.v`**: Core decision engine utilizing hash-based lookup for filtering.
*   **`Top_Level.v`**: Orchestrates the integration of all modules and memory interfaces.

## 🛠️ Project Status & Verification Strategy

**Status: RTL Implementation Complete / Verification in Progress**

The project is currently undergoing a comprehensive verification process:
*   **UVM-Lite Environment:** A SystemVerilog-based testbench utilizing **OOP** principles for modularity[cite: 1].
*   **Constrained-Random Stimulus:** Leveraging **Python (Scapy)** to generate diverse and "corrupt" network traffic (hex files) to test edge cases[cite: 1].
*   **Protocol Integrity:** Utilizing **SystemVerilog Assertions (SVA)** to monitor AXI-Stream handshakes and FSM transitions.

## 💻 Tools
*   **Design & Verification:** Vivado ML Edition (RTL Design, IP Integrator, and integrated xsim simulator).
*   **Scripting:** Python (Scapy) for automated packet generation and stimulus preparation.

## 📜 License
This project is licensed under the MIT License.
