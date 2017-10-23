defmodule PastryProtocol do

  def main(input) do
    [numNodes, numRequests] = input
    numNodes = String.to_integer(numNodes)
    numRequests = String.to_integer(numRequests)
    IO.puts "Nodes   : #{numNodes}"
    IO.puts "Requests: #{numRequests}"
    nodeList = start(numNodes, [], [])
    send self, {:hops}
    loop(nodeList, numNodes, numRequests, [])
  end

  def start(numNodes, nodeList, pidList) when numNodes > 0 do
    # newNode = :crypto.hash(:md5, Integer.to_string(numNodes)) |> Base.encode16()
    newNode = 1000000000000000 + numNodes
    newPid = spawn(PNode, :init, [Integer.to_string(newNode), Integer.to_string(newNode)])
    send newPid, {:console, self}

    if length(pidList) > 100 do
      send newPid, {:init, Enum.at(pidList, length(pidList)-1)}
    else
      if length(pidList) > 0, do: send newPid, {:init, Enum.at(pidList, length(pidList)-1), nodeList, pidList}
    end
    nodeList = nodeList ++ [Integer.to_string(newNode)]
    pidList = pidList ++ [newPid]
    start(numNodes-1, nodeList, pidList)
  end

  def start(numNodes, nodeList, pidList) when numNodes <= 0 do
    [nodeList, pidList]
  end

  def loop(nodeList, numNodes, numRequests, hopArray) do
    receive do
      {:hops} ->
        [nameList, pidList] = nodeList
        :timer.sleep(8000)
        for x <- 1..1 do
          r = round(:math.floor(:rand.uniform() * length(nodeList)))
          send Enum.at(pidList, round(:math.floor(:rand.uniform() * length(pidList)))),
              {:route, Enum.at(nameList, r), Enum.at(pidList, r), Enum.at(nameList, r), 0}
        end
        loop(nodeList, numNodes, numRequests, hopArray)

        {:hopCount, hops} ->
          hopArray = hopArray ++ [hops]
          IO.puts hops
          loop(nodeList, numNodes, numRequests, hopArray)
    end
  end
end
