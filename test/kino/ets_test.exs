defmodule Kino.ETSTest do
  use Kino.LivebookCase, async: true

  import KinoTest.JS.Live

  describe "new/1" do
    test "raises an error when private table is given" do
      tid = :ets.new(:users, [:set, :private])

      assert_raise ArgumentError,
                   "the given table must be either public or protected, but a private one was given",
                   fn ->
                     Kino.ETS.new(tid)
                   end
    end

    test "raises an error when non-existent table is given" do
      tid = :ets.new(:users, [:set, :private])
      :ets.delete(tid)

      assert_raise ArgumentError,
                   "the given table identifier #{inspect(tid)} does not refer to an existing ETS table",
                   fn ->
                     Kino.ETS.new(tid)
                   end
    end
  end

  test "includes table name in the information" do
    tid = :ets.new(:users, [:set, :public])

    widget = Kino.ETS.new(tid)
    data = connect(widget)

    assert %{name: "ETS :users", features: [:refetch, :pagination]} = data
  end

  test "content contains empty columns definition if there are no records" do
    tid = :ets.new(:users, [:set, :public])

    widget = Kino.ETS.new(tid)
    data = connect(widget)

    assert %{
             content: %{
               columns: [%{key: "0", label: "row", type: "tuple"}],
               rows: []
             }
           } = data
  end

  test "content contains columns and rows if there are table records" do
    tid = :ets.new(:users, [:ordered_set, :public])

    :ets.insert(tid, {1, "Jake Peralta"})
    :ets.insert(tid, {2, "Terry Jeffords"})
    :ets.insert(tid, {3, "Amy Santiago"})

    widget = Kino.ETS.new(tid)
    data = connect(widget)

    assert %{
             content: %{
               columns: [
                 %{key: "0", label: "row", type: "tuple"}
               ],
               rows: [
                 %{fields: %{"0" => "{1, \"Jake Peralta\"}"}},
                 %{fields: %{"0" => "{2, \"Terry Jeffords\"}"}},
                 %{fields: %{"0" => "{3, \"Amy Santiago\"}"}}
               ],
               page: 1,
               max_page: 1,
               order_by: nil,
               order: :asc
             }
           } = data
  end

  test "determines enough columns to accommodate longest record" do
    tid = :ets.new(:users, [:ordered_set, :public])

    :ets.insert(tid, {1, "Jake Peralta"})
    :ets.insert(tid, {2, "Sherlock Holmes", 100})
    :ets.insert(tid, {3, "John Watson", 150, :doctor})
    :ets.insert(tid, {4})

    widget = Kino.ETS.new(tid)
    data = connect(widget)

    assert %{
             content: %{
               columns: [
                 %{key: "0", label: "row", type: "tuple"}
               ]
             }
           } = data
  end

  test "supports pagination" do
    tid = :ets.new(:users, [:ordered_set, :public])

    for n <- 1..25, do: :ets.insert(tid, {n})

    widget = Kino.ETS.new(tid)
    data = connect(widget)

    assert %{
             content: %{
               page: 1,
               max_page: 3,
               rows: [%{fields: %{"0" => "{1}"}} | _]
             }
           } = data

    push_event(widget, "show_page", %{"page" => 2})

    assert_broadcast_event(widget, "update_content", %{
      page: 2,
      max_page: 3,
      rows: [%{fields: %{"0" => "{11}"}} | _]
    })
  end
end
