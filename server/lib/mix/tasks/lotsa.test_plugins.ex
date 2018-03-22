defmodule Mix.Tasks.Lotsa.TestPlugins do
  use Mix.Task

  @shortdoc "Runs Lua tests for Lotsa plugins"

  defp hinge_port_pid() do
    # FIXME: Maybe should start HingePort in test, not in app
    :gproc.lookup_pid({:n, :l, :hinge_port})
  end

  def run(args) do
    :gproc.start_link()
    Lotsa.HingePort.start_link()

    plugins_dir = [Mix.Project.build_path, "..", "..", "..", "plugins"] |> Path.join |> Path.expand
    target_plugins = case args do
      [] -> File.ls!(plugins_dir)
      targets -> targets
    end

    Enum.each target_plugins, fn plugin ->
      IO.puts("Testing plugin \"#{plugin}\"")
      test_plugin(plugin)
    end
  end

  defp test_plugin(plugin) do
    testset = Lotsa.HingePort.load_tests(hinge_port_pid(), plugin)
    IO.inspect(testset)
    if Map.has_key?(testset, "tests") do
      universe_def = setup_test_universe(plugin)
      Enum.each testset["tests"], fn {name, test} ->
        run_test(universe_def, testset, "#{plugin}::#{name}", test)
      end
    else
      # TODO Complain if the plugin doesn't exist at all
      IO.puts("No tests provided for plugin \"#{plugin}\"")
    end
  end

  defp setup_test_universe(plugin) do
    Lotsa.HingePort.load_config(
      hinge_port_pid(),
      %{
        url: "test://#{plugin}",
        plugins: [ [plugin, "*"] ]
      }
    )
  end

  defp run_test(universe_def, testset, test_name, test) do
    initial_chunk = Lotsa.Chunk.new(
      {0,0,0,0},
      string_to_block_types(testset, test, "start")
    )
    {:ok, sim} = Lotsa.Simulator.start(universe_def, %{chunks: [initial_chunk]})
    try do
      {:ok, chunk} = Lotsa.Simulator.get_chunk(sim, {0,0,0,0})
      IO.inspect(test_name)
      IO.inspect(chunk)
    after
      Lotsa.Simulator.stop(sim)
    end
  end

  def string_to_block_types(testset, test, state_name) do
    str = test[state_name]
    Enum.map String.split(str), fn(line) ->
      Enum.map String.codepoints(line), fn(char) ->
        case char do
          "-" -> 1
          "S" -> 2
        end
      end
    end
  end
end
