defmodule YellowDog.Mnesia.Schema do
  require YellowDog.Mnesia.Mnesia

  @moduledoc """
  Module to interact with the database schema.

  For persisting data, Mnesia databases need to be created on disk. This
  module provides an interface to create the database on the disk of the
  specified nodes. Most of the time that is usually the node that the
  application is running on.

  ```
  # Create schema on current node
  YellowDog.Mnesia.Schema.create([ node() ]

  # Create schema on many nodes
  node_list = [node(), :alice@host_x, :bob@host_y, :eve@host_z]
  YellowDog.Mnesia.Schema.create(node_list)
  ```

  Important thing to note here is that only the nodes where data has to
  be persisted to disk have to be included. RAM-only nodes should be
  left out. Disk schemas can also be deleted by calling `delete/1` and
  you can get information about them by calling `info/0`.


  ## Example

  ```elixir
  # The nodes where you want to persist
  nodes = [ node() ]

  # Create the schema
  YellowDog.Mnesia.stop
  YellowDog.Mnesia.Schema.create(nodes)
  YellowDog.Mnesia.start

  # Create disc copies of your tables
  YellowDog.Mnesia.Table.create!(TableA, disc_copies: nodes)
  YellowDog.Mnesia.Table.create!(TableB, disc_copies: nodes)
  ```

  """

  # Public API
  # ----------

  @doc """
  Creates a new database on disk on the specified nodes.

  Calling `:mnesia.create_schema` for a custom path throws an exception
  if that path does not exist. YellowDog.Mnesia's version avoids this by ensuring
  that the directory exists.

  Also see `:mnesia.create_schema/1`.
  """
  @spec create(list(node)) :: :ok | {:error, any}
  def create(nodes) do
    if path = Application.get_env(:mnesia, :dir) do
      :ok = File.mkdir_p!(path)
    end

    :create_schema
    |> YellowDog.Mnesia.Mnesia.call_and_catch([nodes])
    |> YellowDog.Mnesia.Mnesia.handle_result()
  end

  @doc """
  Deletes the database previously created by `create/1` on the specified
  nodes.

  Use this with caution, as it makes persisting data obsolete. Also see
  `:mnesia.delete_schema/1`.
  """
  @spec delete(list(node)) :: :ok | {:error, any}
  def delete(nodes) do
    :delete_schema
    |> YellowDog.Mnesia.Mnesia.call_and_catch([nodes])
    |> YellowDog.Mnesia.Mnesia.handle_result()
  end

  @doc """
  Prints schema information about all Tables to the console.
  """
  @spec info() :: :ok
  def info do
    :schema
    |> YellowDog.Mnesia.Mnesia.call_and_catch()
    |> YellowDog.Mnesia.Mnesia.handle_result()
  end

  @doc """
  Prints schema information about the specified Table to the console.
  """
  @spec info(YellowDog.Mnesia.Table.name()) :: :ok
  def info(table) do
    :schema
    |> YellowDog.Mnesia.Mnesia.call_and_catch([table])
    |> YellowDog.Mnesia.Mnesia.handle_result()
  end

  @doc """
  Sets the schema storage mode for the specified node.

  Useful when you want to change the schema mode on the fly,
  usually when connecting to a new, unsynchronized node on
  discovery at runtime.

  The mode can only be `:ram_copies` or `:disc_copies`. If the
  storage mode is set to `ram_copies`, then no table on that
  node can be disc-resident.

  This just calls `YellowDog.Mnesia.Table.set_storage_type/3` underneath
  with `:schema` as the table. Also see
  `:mnesia.change_table_copy_type/3` for more details.


  ## Example

  ```
  YellowDog.Mnesia.Schema.set_storage_type(:node@host, :disc_copies)
  ```
  """
  @spec set_storage_type(node, YellowDog.Mnesia.Table.storage_type()) :: :ok | {:error, any}
  def set_storage_type(node, type) do
    YellowDog.Mnesia.Table.set_storage_type(:schema, node, type)
  end
end
