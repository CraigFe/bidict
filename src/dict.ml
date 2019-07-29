(*
 * Copyright (c) 2013-2019 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

module type IO = Io.S

module type S = sig
  type t

  val find : t -> int -> string option

  val index : t -> string -> int option

  val sync : t -> unit

  val v : ?fresh:bool -> ?readonly:bool -> ?capacity:int -> string -> t

  val clear : t -> unit
end

let src = Logs.Src.create "dict" ~doc:"Dict"

let current_version = "00000001"

exception RO_Not_Allowed

module Log = (val Logs.src_log src : Logs.LOG)

module type CODE = sig
  val to_bin_string : int32 -> string

  val decode_bin : string -> int -> int32
end

module Make (IO : IO) (C : CODE) = struct
  let ( -- ) = Int64.sub

  type t = {
    capacity : int;
    cache : (string, int) Hashtbl.t;
    index : (int, string) Hashtbl.t;
    io : IO.t
  }

  let append_string t v =
    let len = Int32.of_int (String.length v) in
    let buf = C.to_bin_string len ^ v in
    IO.append t.io buf

  let refill ~from t =
    let len = Int64.to_int (IO.offset t.io -- from) in
    let raw = Bytes.create len in
    let n = IO.read t.io ~off:from raw in
    assert (n = len);
    let raw = Bytes.unsafe_to_string raw in
    let rec aux n offset =
      if offset >= len then ()
      else
        let v = C.decode_bin raw offset in
        let len = Int32.to_int v in
        let v = String.sub raw (offset + 4) len in
        Hashtbl.add t.cache v n;
        Hashtbl.add t.index n v;
        (aux [@tailcall]) (n + 1) (offset + 4 + len)
    in
    (aux [@tailcall]) (Hashtbl.length t.cache) 0

  let sync_offset t =
    let former_log_offset = IO.offset t.io in
    let log_offset = IO.force_offset t.io in
    if log_offset > former_log_offset then refill ~from:former_log_offset t

  let sync t = IO.sync t.io

  let index t v =
    Log.debug (fun l -> l "[dict] index %S" v);
    if IO.readonly t.io then sync_offset t;
    try Some (Hashtbl.find t.cache v)
    with Not_found ->
      if IO.readonly t.io then raise RO_Not_Allowed;
      let id = Hashtbl.length t.cache in
      if id > t.capacity then None
      else (
        if IO.readonly t.io then raise RO_Not_Allowed;
        append_string t v;
        Hashtbl.add t.cache v id;
        Hashtbl.add t.index id v;
        Some id )

  let find t id =
    if IO.readonly t.io then sync_offset t;
    Log.debug (fun l -> l "[dict] find %d" id);
    try Some (Hashtbl.find t.index id) with Not_found -> None

  let clear t =
    IO.clear t.io;
    Hashtbl.clear t.cache;
    Hashtbl.clear t.index

  let v ?(fresh = true) ?(readonly = false) ?(capacity = 100_000) file =
    let io = IO.v ~fresh ~version:current_version ~readonly file in
    let cache = Hashtbl.create 997 in
    let index = Hashtbl.create 997 in
    let t = { capacity; index; cache; io } in
    refill ~from:0L t;
    t
end
