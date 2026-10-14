# CG Biometric desktop app: backend API specification

What the Windows app (`cg_biometric`) sends to the server and what it expects back.
Everything goes to **one gateway URL** with an `action` field.

## 1. Connection

| Item | Value |
|---|---|
| Gateway URL | `<BASE_URL>/biometric_gateway/index.php` |
| `BASE_URL` | Set on the login screen (double-click the page, type `allowtoupdateendpoint`). Example: `https://erp.example.com/admin/web`. A value that already ends in `.php` is used as given. |
| Fallback when no base URL is set | `https://www.cgrems.com/cg_helpdesk/apis/biometric_api.php` |
| Method | `POST` |
| Request header | `Content-Type: application/json` |
| Request body | one JSON object, always containing `action` |
| Timeout | 15 seconds per call (the app treats a timeout as "server unreachable", not as "logged out") |
| HTTP status | the app requires **HTTP 200**; any other status is shown as "Server returned HTTP <code>" |
| CORS | not needed (desktop app). Needed only if a web build is made later. |

### Response envelope (every action, always HTTP 200)

```json
{ "status": true, "message": "text", "data": ... }
```

`status=false` means the call was refused; the app shows `message` to the user.

### Session handling the app expects from the server

* `login` returns an `api_token` valid for 5 hours. The app sends it as `api_token` in every other call.
* If a token is invalid or expired the server must answer with `status:false` and a `message` containing one of these phrases (case-insensitive): **`unauthorized`**, `invalid token`, `token expired`, `session expired`, `invalid api token`. The app then clears its saved login, closes all dialogs and returns to the login screen with the message "Session out. Please sign in again."
* The app calls `check_status` on startup and then every 30 s (every 5 s while the server is unreachable), so expiry is noticed within about 30 s even when the user is idle.

---

## 2. Actions

### 2.1 `login`

Request:
```json
{ "action": "login", "username": "device1", "password": "Secret123!" }
```

Success response (`data` is stored on the device and used on the dashboard):
```json
{ "status": true, "message": "Login successful", "data": {
  "id": 1,
  "username": "device1",
  "project_name": "Anchorage Islamabad",
  "project_logo": "https://.../logo.png",
  "project_email": "a@b.com",
  "project_contact": "051-...",
  "project_address": "....",
  "dashboard_endpoint": "https://.../index.php",
  "get_data_endpoint": "https://.../index.php?r=biometric/get-data&cnic=",
  "post_data_endpoint": "https://.../index.php?r=biometric/post-data",
  "api_token": "64 hex characters",
  "token_expiry": "2026-10-12 02:08:26"
} }
```
Failure: `{ "status": false, "message": "Invalid username or password" }` (the message is shown as-is).
The app stores: `username`, `api_token`, `get_data_endpoint`, `post_data_endpoint` and the whole `data` object. The password is **not** stored.

### 2.2 `logout`

```json
{ "action": "logout", "api_token": "<token>" }
```
Token must be dropped immediately. Response content is ignored. The app clears its local session even when this call fails.

### 2.3 `check_status`

```json
{ "action": "check_status", "api_token": "<token>" }
```
Valid token: `{ "status": true, "message": "API is running" }`.
Invalid token: `{ "status": false, "message": "Unauthorized" }`.
Used as the "Server connected" indicator and for session expiry detection.

### 2.4 `check_cnic`  (called after the record lookup, before scanning)

```json
{ "action": "check_cnic", "api_token": "<token>", "cnic": "3520112345671", "transfer_id": 12 }
```
`transfer_id` is sent only for transfer screens (integer when numeric).

Response:
```json
{ "status": true, "message": "Not registered: biometric registration is required first",
  "data": { "cnic": "3520112345671", "registered": false,
            "registered_at": null, "updated_at": null,
            "next": "register", "verified": null, "verified_at": null } }
```
The app reads `data.next`:

| `next` | App behaviour |
|---|---|
| `register` | Verification screens stop with the message ("Not registered...") and do not open the scanner. Registration screens continue. |
| `verify` | Registration screens show "A fingerprint is already registered for this CNIC. Saving will replace it." and continue. Verification continues. |
| `continue` | Shows "Already verified on this transfer". Verification stops; registration continues. |

If this call fails or `status` is false the app ignores it and continues.

### 2.5 `get_data`  (membership / transfer member details)

```json
{ "action": "get_data", "api_token": "<token>", "cnic": "3520112345671", "file_no": "IACH-999" }
```
* `file_no` is sent for **allotment** screens only. For **transfer** screens only `cnic` is sent (see the note below).
* The app needs the server answer to be the project's answer relayed unchanged:

```json
{ "status": true, "message": "...", "data": [
  { "member_name": "Qamar Ali", "relation": "S/O", "sodowo": "M Rukhsar",
    "consumer_no": "000000000000000999", "plot_no": "TEST_101", "size": "1000 Sq Yds",
    "sector_name": "E", "project": "...", "comment": "Approved by ...",
    "image": "https://.../photo.jpg",
    "file_no": "IACH-999", "transfer_id": 51 }
] }
```
* `data.status` must be `true` and `data.data` must be a **list**. Otherwise the app shows `data.message` (or the envelope `message`) as "User Not Found".
* Displayed fields: `member_name`, `relation`, `sodowo` (father/husband name), `consumer_no`, `plot_no`, `size`, `sector_name`, `comment` (shown as the status label), `image` (photo URL). The CNIC and file / transfer reference shown on screen are what the operator typed.
* **One record is shown.** The app picks the record whose `file_no` / `file_number` / `fileno` (allotment) or `transfer_id` / `transfer_request_id` / `transfer_no` (transfer) equals the typed reference; if none carries such a field it uses the **first** record. 
  **Backend recommendation:** for allotments filter by `file_no`; for transfers accept an optional `transfer_id` in `get_data` and return only that transfer's member row, so the first record is always the right one. (The app does not send `transfer_id` to `get_data` today; tell us if you add support and we will send it.)
* When `file_no` is sent, the CNIC must belong to that file, otherwise respond `status:true/false` with message like `"CNIC ... does not belong to file ..."`.

### 2.6 `post_data`  (registration: save / replace the fingerprint)

```json
{
  "action": "post_data",
  "api_token": "<token>",
  "type": "allotment",
  "cnic": "3520112345671",
  "file_no": "IACH-999",
  "fingerprint_snapshots": ["<base64 PNG>"]
}
```
Transfer variant: `"type": "transfer"`, `"transfer_id": 51` (integer when numeric, otherwise string) instead of `file_no`.

Field rules the app follows (the server must validate the same):

| Field | Rule |
|---|---|
| `type` | `allotment` or `transfer` (required) |
| `cnic` | exactly 13 digits (the app validates before sending) |
| `file_no` | sent only when `type=allotment`; CNIC must belong to this file |
| `transfer_id` | sent only when `type=transfer`; CNIC must be a member of this transfer request |
| `fingerprint_snapshots` | JSON array with **one** string: the fingerprint image as **Base64 of a PNG** (see section 3) |

Server behaviour required:
* replace every stored fingerprint of the CNIC with the snapshots sent; keep the first registration date, update the update date;
* record the capture as verified on every open transfer the CNIC takes part in (and on `transfer_id` when sent);
* on a missing or mismatching value refuse with a message naming it and store nothing.

Response read by the app:
```json
{ "status": true, "message": "Endpoint response received",
  "data": { "status": true, "message": "Fingerprint saved" } }
```
* Outer `status:false` -> error dialog with `message`.
* Inner `data.status:false` -> error dialog with `data.message`.
* Success when both are true; the app shows "Biometric Registration successful." and closes the dialog.

### 2.7 `verify_data`  (verification: compare, store nothing)

Body is **identical to `post_data`** with `"action": "verify_data"`.

Response read by the app:

* match:
  ```json
  { "status": true, "message": "Endpoint response received",
    "data": { "status": true, "message": "Fingerprint Verified",
              "data": { "membership": [ ... ] } } }
  ```
  The app shows a green bar with `data.message`.
* no match:
  ```json
  { "status": true, "message": "Endpoint response received",
    "data": { "status": false, "message": "Fingerprint not found" } }
  ```
  The app shows a red bar with `data.message`.
* Outer `status:false` (validation refused) -> red bar with `message`.

The result (match or not) must be recorded on every open transfer the CNIC is part of, plus `transfer_id` when sent. A failed attempt must never clear an earlier successful check.

### 2.8 `verify_biometric_image`  (reserved)

Present in the app code but **not reachable from the UI** (the Image Capturing screen was removed from the dashboard).

```json
{ "action": "verify_biometric_image", "api_token": "<token>", "cnic": "3520112345671", "base64_image": "<base64>" }
```
Expected response: `{ "status": true, "data": { "data": ... } }`. Implement only if Image Capturing is brought back.

---

## 3. Fingerprint data format (`fingerprint_snapshots[0]`)

| Property | Value |
|---|---|
| Encoding | Base64 (standard alphabet, no line breaks) of the **PNG file bytes** |
| Image | 8-bit **greyscale PNG**, one channel |
| Size (U.are.U 4500 via Windows Biometric Framework) | 320 x 362 px (about 115 KB raw, roughly 60-100 KB as PNG; Base64 adds ~33%) |
| Resolution | 508 dpi (from the sensor header; not embedded in the PNG) |
| Background | white (255 / 254); ridges dark |
| Count | exactly one snapshot per request |

Other readers can give a different width / height; the server must not assume 320 x 362. Allow request bodies of **at least 1 MB** (PHP `post_max_size`, `memory_limit`, web-server body limit). The column that stores it must be `LONGTEXT` / `MEDIUMBLOB` (the doc already notes `biometric.fingerprint` becomes `LONGTEXT`).

How the app gets the image: it captures a **raw** sample through the Windows Biometric Framework (`winbio.dll`, `WinBioCaptureSample` with raw flag, which requires administrator rights, so the app always runs elevated), converts the ANSI/INCITS 381 finger-image record to a PNG, and sends that PNG. No minutiae template is generated on the device; **matching must be done on the server** (compare the stored image with the new image).

---

## 4. Screen -> request map

| Screen / event | Calls, in order |
|---|---|
| App start with saved login | `check_status` (then every 30 s / 5 s when unreachable) |
| Login | `login` |
| Allotment / Transfer **Registration**, press *Check* | `get_data` -> `check_cnic` -> (scan on device) |
| Registration, press *Save Fingerprint* | `post_data` |
| Allotment / Transfer **Verification**, press *Check* | `get_data` -> `check_cnic` -> (scan on device; stops early on `register` / `continue`) |
| Verification, press *Verify Fingerprint* | `verify_data` |
| Logout | `logout` |
| Any call returning "Unauthorized" etc. | app returns to login (see section 1) |

### Typical values

| Input in the app | Request field |
|---|---|
| File No (allotment) | `file_no` (string) |
| Transfer ID (transfer) | `transfer_id` (integer if digits only) |
| CNIC (13 digits) | `cnic` (string, digits only) |
| Allotment screens | `type = "allotment"` |
| Transfer screens | `type = "transfer"` |

## 5. Server checklist

1. Always answer HTTP 200 with `{status, message, data}`.
2. Return the exact phrase **"Unauthorized"** (or another listed phrase) for an invalid or expired token on **every** action except `login`.
3. `check_cnic` must exist and return `data.next` = `register` / `verify` / `continue`.
4. `get_data`: list in `data.data`; filter by `file_no`; ideally include `file_no` / `transfer_id` in each record and accept `transfer_id`.
5. `post_data` / `verify_data`: validate `type` + `file_no`/`transfer_id` + 13-digit `cnic`; read `fingerprint_snapshots[0]` as Base64 PNG; put the real outcome in the inner `data.status` / `data.message` (`"Fingerprint Verified"`, `"Fingerprint not found"`).
6. Accept JSON bodies of at least 1 MB.
7. Log tokens masked and templates as length + checksum only.

---

## 6. UPDATE: three operations (supersedes the older register/verify rows above)

The app now offers **Member Registration**, **Allotment Verification** and **Transfer Verification**
(see `C:\wamp64\www\admin\docs\biometric-api.md`, section 9).

| Operation | Action sent | Body fields |
|---|---|---|
| Member Registration | `post_data` | `type:"registration"`, `cnic`, `fingerprint_snapshots:[<base64 PNG>]` (no `file_no` / `transfer_id`) |
| Allotment Verification | `verify_data` | `type:"allotment"`, `cnic`, `file_no`, `fingerprint_snapshots:[<base64 PNG of the live scan>]` |
| Transfer Verification | `verify_data` | `type:"transfer"`, `cnic`, `transfer_id`, `fingerprint_snapshots:[<base64 PNG of the live scan>]` |

* **Registration is done once.** The app checks `check_cnic` first. If the CNIC is already registered it shows a warning and asks for confirmation before sending a replacing `post_data`.
* **Verifications always send a live scan.** The app captures a finger and sends it as `fingerprint_snapshots`; the server matches it against the fingerprint saved at registration and records the result (on the transfer, for transfer verification).
  * match -> `"Fingerprint Verified"`, `data.method = "scan"`; the app shows "<message> - saved".
  * no match -> `"Fingerprint not found"`; the app shows **"Fingerprint not matching. Please try again."** (any other server message, e.g. low image quality, is shown as sent).
* A verification for a CNIC that is not registered must answer `"Not registered: biometric registration is required first"` (`data.next = "register"`). The app already stops before this using `check_cnic`.
* `get_data` now also sends `transfer_id` for transfer screens (`file_no` for allotment, neither for registration). Rows should carry `file_no` / `transfer_id` so the app shows exactly one record.
