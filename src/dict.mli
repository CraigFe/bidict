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

(** The exception raised when illegal operation is attempted on a read_only
    dict. *)
exception RO_Not_Allowed

(** Dict module signature *)
module type S = sig
  type t

  val find : t -> int -> string option

  val index : t -> string -> int option

  val sync : t -> unit
  (** Synchronise the dictionary with the IO backend. *)

  val v : ?fresh:bool -> ?readonly:bool -> ?capacity:int -> string -> t
  (** The constructor for dictionaries.
      @param fresh
      @param shared
      @param readonly whether read-only mode is enabled for this dictionary. *)

  val clear : t -> unit
end

module type CODE = sig
  val to_bin_string : int32 -> string

  val decode_bin : string -> int -> int32
end

module type IO = Io.S

module Make (IO : IO) (C : CODE) : S
