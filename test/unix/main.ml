module A = Alcotest

module D = Dict_unix.Make (struct
  let to_bin_string = Irmin.Type.(to_bin_string int32)

  let decode_bin = Irmin.Type.(decode_bin int32) ?headers:None
end)

let test_file = Filename.concat "_build" "test-dict-unix"

let test_dict () =
  let dict = D.v ~fresh:true test_file in
  let index = D.index dict in
  index "foo" |> A.(check int) "foo" 0;
  index "foo" |> A.(check int) "foo" 0;
  index "bar" |> A.(check int) "bar" 1;
  index "toto" |> A.(check int) "toto" 2;
  index "titiabc" |> A.(check int) "titiabc" 3;
  index "foo" |> A.(check int) "foo" 0

let test_readonly_dict () =
  let ignore_int (_ : int) = () in
  let w = D.v ~fresh:true test_file in
  let r = D.v ~fresh:false ~readonly:true test_file in
  let check_index k i = A.(check int) k i (D.index r k) in
  let check_find k i = A.(check (option string)) k (Some k) (D.find r i) in
  let check_none k i = A.(check (option string)) k None (D.find r i) in
  let check_raise k =
    try
      ignore_int (D.index r k);
      A.fail "RO dict should not be writable"
    with Dict.RO_Not_Allowed -> ()
  in
  ignore_int (D.index w "foo");
  ignore_int (D.index w "foo");
  ignore_int (D.index w "bar");
  ignore_int (D.index w "toto");
  ignore_int (D.index w "titiabc");
  ignore_int (D.index w "foo");
  D.sync w;
  check_index "titiabc" 3;
  check_index "bar" 1;
  check_index "toto" 2;
  check_find "foo" 0;
  check_raise "xxx";
  ignore_int (D.index w "hello");
  check_raise "hello";
  check_none "hello" 4;
  D.sync w;
  check_find "hello" 4

let () =
  A.run "dict"
    [ ("read-write", [ A.test_case "misc" `Quick test_dict ]);
      ("read-only", [ A.test_case "misc" `Quick test_readonly_dict ])
    ]
