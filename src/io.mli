module type S = sig
  type t

  val v : fresh:bool -> version:string -> readonly:bool -> string -> t

  val name : t -> string

  val offset : t -> int64

  val force_offset : t -> int64

  val readonly : t -> bool

  val read : t -> off:int64 -> bytes -> int

  val clear : t -> unit

  val sync : t -> unit

  val version : t -> string

  val append : t -> string -> unit
end
