# UcapHutang

Aplikasi iOS untuk mencatat utang, piutang, dan split bill melalui suara, meninjau hasil ekstraksi on-device, serta melihat saldo dan riwayat per orang.

## Fitur utama

- **Draft** — hasil input yang perlu ditinjau sebelum masuk buku.
- **Catat** — pilih flow Personal atau Split Bill, lalu input dengan suara.
- **Riwayat** — saldo bersih per orang, log transaksi, dan log pembayaran yang dilakukan di luar aplikasi.

Dokumen teknis:

- `docs/ARCHITECTURE_PLAN.md`
- `docs/QWEN_MIGRATION_PLAN.md`
- `docs/PROJECT_REMEDIATION_PLAN.md`

## Requirements

- macOS dengan Xcode 26.6 atau versi yang kompatibel dengan project
- iOS 26.5 deployment target saat ini
- Physical iPhone/iPad untuk validasi performa MLX
- Ruang penyimpanan yang cukup untuk model Qwen dan hasil build

## Setup setelah clone

1. Clone dan buka project:

   ```sh
   git clone https://github.com/AdhiKrisna/UcapHutang.git
   cd UcapHutang
   open UcapHutang.xcodeproj
   ```

2. Pilih development team dan bundle identifier yang valid pada target `UcapHutang` jika signing lokal berbeda.

3. Pulihkan model sesuai bagian berikut, lalu build project. Aplikasi menggunakan SwiftData untuk Draft/Riwayat dan Qwen lokal untuk membantu ekstraksi ucapan.

## Setup model Qwen dari GitHub Release

Model tidak masuk Git. Folder model, file `.safetensors`, `.gguf`, dan arsip Qwen telah dimasukkan ke `.gitignore`.

Gunakan model dari release `model-qwen3-0.6b-v1`:

1. Unduh [`Qwen3-0.6B-4bit.zip`](https://github.com/AdhiKrisna/UcapHutang/releases/download/model-qwen3-0.6b-v1/Qwen3-0.6B-4bit.zip).
2. Cocokkan SHA-256 arsip dengan:

   ```text
   3eb0e4e690cae81104ef834e3dc5142edc3725786cec610fb00145d03d60e7f2
   ```
3. Extract hingga struktur akhirnya persis:

   ```text
   UcapHutang/Resources/Models/Qwen3-0.6B-4bit/
   ├── config.json
   ├── tokenizer.json
   ├── tokenizer_config.json
   └── model.safetensors
   ```

   Jika model memakai weight shards, pertahankan semua shard dan index JSON dari asset.

4. Project memakai file-system-synchronized target. Pastikan seluruh file model terlihat di navigator Xcode dan muncul pada `Copy Bundle Resources`. Xcode saat ini dapat meratakan isi folder ke root app bundle; loader mendukung layout hasil build tersebut dan layout nested yang didokumentasikan di atas.
5. Swift packages sudah dikonfigurasi dan dipin ke MLX Swift `0.31.6`, MLX Swift LM `3.31.4`, dan Swift Transformers `1.3.4`.
6. Jalankan di physical device. Simulator build hanya memverifikasi kompilasi dan packaging, bukan kelayakan memori atau performa inference.

## Privacy dan data

Target arsitektur memproses speech dan Qwen secara on-device. Raw transcript dan raw model response dipertahankan sebagai evidence pada draft agar kesalahan STT dapat dibedakan dari kesalahan parsing model. Jangan memasukkan data uji sensitif ke repository.

## Status implementasi

Saat ini tersedia implementasi feature-first MVVM:

- domain model draft, participant, ledger charge/payment
- repository protocol dan SwiftData persistence dengan blocking error jika storage gagal dibuka
- tab Draft/Catat/Riwayat
- Draft filtering dan shared Review form
- ledger projection serta pencatatan pembayaran di luar aplikasi
- design tokens dan reusable components sementara
- Apple Speech `id-ID`, Contacts resolution, dan mode-specific Qwen prompt
- MLX adapter lokal yang tidak melakukan fallback download dari Hugging Face

Unit-test target dan model readiness UI sudah tersedia. Strict schema hardening lengkap dan benchmark perangkat tetap menjadi pekerjaan prioritas di `docs/PROJECT_REMEDIATION_PLAN.md`.
