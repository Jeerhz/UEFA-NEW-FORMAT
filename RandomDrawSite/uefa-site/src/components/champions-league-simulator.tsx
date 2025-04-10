"use client";

import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Trophy,
  AlertCircle,
  Dices,
  Home,
  ExternalLink,
  Shield,
  BarChart4,
  Clock,
} from "lucide-react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Separator } from "@/components/ui/separator";

// Mock data for the simulator
const TEAMS_DATA = {
  pot1: [
    "Manchester City",
    "Bayern Munich",
    "Real Madrid",
    "PSG",
    "Liverpool",
    "Inter Milan",
    "Dortmund",
    "Barcelona",
    "RB Leipzig",
  ],
  pot2: [
    "Atletico Madrid",
    "Bayer Leverkusen",
    "Atalanta",
    "Juventus",
    "Benfica",
    "Arsenal",
    "Club Brugge",
    "Shakhtar",
    "FC Porto",
  ],
  pot3: [
    "Salzburg",
    "Napoli",
    "Sporting CP",
    "PSV",
    "Lille",
    "AC Milan",
    "Young Boys",
    "Feyenoord",
    "Celtic",
  ],
  pot4: [
    "Dinamo Zagreb",
    "Monaco",
    "Sturm Graz",
    "Sparta Prague",
    "Aston Villa",
    "Bologna",
    "Girona",
    "Brest",
    "Slovan Bratislava",
  ],
};

export function ChampionsLeagueSimulator() {
  const [currentPot, setCurrentPot] = useState(1);
  const [currentTeam, setCurrentTeam] = useState("");
  const [currentStep, setCurrentStep] = useState<
    "selectTeam" | "showOpponents" | "drawOpponents"
  >("selectTeam");
  const [drawComplete, setDrawComplete] = useState(false);
  const [drawResults, setDrawResults] = useState<Record<string, any>>({});
  const [potProgress, setPotProgress] = useState<Record<number, number>>({
    1: 0,
    2: 0,
    3: 0,
    4: 0,
  });
  const [activeTab, setActiveTab] = useState("pot1");
  const [admissibleOpponents, setAdmissibleOpponents] = useState<string[]>([]);
  const [selectedOpponents, setSelectedOpponents] = useState<{
    home: string;
    away: string;
  }>({ home: "", away: "" });

  // Initialize draw results structure
  useEffect(() => {
    const initialResults: Record<string, any> = {};

    Object.entries(TEAMS_DATA).forEach(([pot, teams]) => {
      teams.forEach((team) => {
        initialResults[team] = {
          pot: pot,
          opponents: {
            pot1: { home: "", away: "" },
            pot2: { home: "", away: "" },
            pot3: { home: "", away: "" },
            pot4: { home: "", away: "" },
          },
        };
      });
    });

    setDrawResults(initialResults);
  }, []);

  const handleStartDraw = () => {
    // Reset the draw
    setCurrentPot(1);
    setCurrentTeam("");
    setCurrentStep("selectTeam");
    setDrawComplete(false);
    setPotProgress({ 1: 0, 2: 0, 3: 0, 4: 0 });
    setActiveTab("pot1");
  };

  const handleSelectTeam = () => {
    // Get available teams from current pot that haven't been processed yet
    const potKey = `pot${currentPot}` as keyof typeof TEAMS_DATA;
    const availableTeams = TEAMS_DATA[potKey].filter((team) => {
      const teamData = drawResults[team];
      const potOpponents = teamData?.opponents[`pot${currentPot}`];
      return !(potOpponents?.home && potOpponents?.away);
    });

    if (availableTeams.length === 0) {
      // Move to next pot if all teams in current pot are processed
      if (currentPot < 4) {
        setCurrentPot((prev) => prev + 1);
        setActiveTab(`pot${currentPot + 1}`);
        setCurrentStep("selectTeam");
      } else {
        setDrawComplete(true);
      }
      return;
    }

    // Randomly select a team from available teams
    const randomIndex = Math.floor(Math.random() * availableTeams.length);
    const selectedTeam = availableTeams[randomIndex];
    setCurrentTeam(selectedTeam);

    // Generate admissible opponents (simplified for demo)
    generateAdmissibleOpponents(selectedTeam);

    setCurrentStep("showOpponents");
  };

  const generateAdmissibleOpponents = (team: string) => {
    // In a real implementation, this would use complex logic to determine valid opponents
    // For this demo, we'll use a simplified approach
    const potKey = `pot${currentPot}` as keyof typeof TEAMS_DATA;
    const potOpponents = TEAMS_DATA[potKey].filter(
      (t) =>
        t !== team &&
        !Object.values(drawResults[team]?.opponents || {}).some(
          (opp) => opp.home === t || opp.away === t
        )
    );

    setAdmissibleOpponents(potOpponents);
  };

  const handleDrawOpponents = () => {
    if (admissibleOpponents.length < 2) return;

    // Randomly select two opponents
    const shuffled = [...admissibleOpponents].sort(() => 0.5 - Math.random());
    const home = shuffled[0];
    const away = shuffled[1];

    setSelectedOpponents({ home, away });

    // Update draw results
    const potKey = `pot${currentPot}` as keyof typeof TEAMS_DATA;

    // Update current team's opponents
    const updatedResults = { ...drawResults };
    updatedResults[currentTeam].opponents[potKey] = { home, away };

    // Update opponents' records
    updatedResults[home].opponents[`pot${currentPot}`].away = currentTeam;
    updatedResults[away].opponents[`pot${currentPot}`].home = currentTeam;

    setDrawResults(updatedResults);

    // Update progress for current pot
    setPotProgress((prev) => ({
      ...prev,
      [currentPot]: prev[currentPot] + 1,
    }));

    setCurrentStep("drawOpponents");

    // After a delay, move to next team
    setTimeout(() => {
      setCurrentTeam("");
      setCurrentStep("selectTeam");
    }, 2000);
  };

  const renderTeamOpponents = (team: string) => {
    const teamData = drawResults[team];
    if (!teamData) return null;

    return (
      <tr className="border-b border-slate-200 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors h-8">
        <td className="px-4 py-1 font-medium whitespace-nowrap">{team}</td>
        <td className="px-2 py-1">
          {teamData.opponents.pot1.home && (
            <Badge
              variant="outline"
              className="justify-center w-full font-normal text-xs py-0 h-5 truncate"
            >
              {teamData.opponents.pot1.home}
            </Badge>
          )}
        </td>
        <td className="px-2 py-1">
          {teamData.opponents.pot1.away && (
            <Badge
              variant="outline"
              className="justify-center w-full font-normal text-xs py-0 h-5 truncate"
            >
              {teamData.opponents.pot1.away}
            </Badge>
          )}
        </td>
        <td className="px-2 py-1">
          {teamData.opponents.pot2.home && (
            <Badge
              variant="outline"
              className="justify-center w-full font-normal text-xs py-0 h-5 truncate"
            >
              {teamData.opponents.pot2.home}
            </Badge>
          )}
        </td>
        <td className="px-2 py-1">
          {teamData.opponents.pot2.away && (
            <Badge
              variant="outline"
              className="justify-center w-full font-normal text-xs py-0 h-5 truncate"
            >
              {teamData.opponents.pot2.away}
            </Badge>
          )}
        </td>
        <td className="px-2 py-1">
          {teamData.opponents.pot3.home && (
            <Badge
              variant="outline"
              className="justify-center w-full font-normal text-xs py-0 h-5 truncate"
            >
              {teamData.opponents.pot3.home}
            </Badge>
          )}
        </td>
        <td className="px-2 py-1">
          {teamData.opponents.pot3.away && (
            <Badge
              variant="outline"
              className="justify-center w-full font-normal text-xs py-0 h-5 truncate"
            >
              {teamData.opponents.pot3.away}
            </Badge>
          )}
        </td>
        <td className="px-2 py-1">
          {teamData.opponents.pot4.home && (
            <Badge
              variant="outline"
              className="justify-center w-full font-normal text-xs py-0 h-5 truncate"
            >
              {teamData.opponents.pot4.home}
            </Badge>
          )}
        </td>
        <td className="px-2 py-1">
          {teamData.opponents.pot4.away && (
            <Badge
              variant="outline"
              className="justify-center w-full font-normal text-xs py-0 h-5 truncate"
            >
              {teamData.opponents.pot4.away}
            </Badge>
          )}
        </td>
      </tr>
    );
  };

  const getPotColor = (pot: number) => {
    const colors = {
      1: "bg-[#0e1e5b] dark:bg-[#0e1e5b]",
      2: "bg-[#1e3a8a] dark:bg-[#1e3a8a]",
      3: "bg-[#2563eb] dark:bg-[#2563eb]",
      4: "bg-[#3b82f6] dark:bg-[#3b82f6]",
    };
    return colors[pot as keyof typeof colors];
  };

  return (
    <div className="space-y-8">
      <div className="grid md:grid-cols-3 gap-6">
        {/* Draw Controls */}
        <Card className="md:col-span-1 border border-slate-200 dark:border-slate-800 shadow-md overflow-hidden">
          <CardHeader className="pb-4">
            <div className="flex items-center space-x-2">
              <Dices className="h-5 w-5" />
              <CardTitle className="text-lg font-bold text-[#0e1e5b]">
                Draw Controls
              </CardTitle>
            </div>
            <CardDescription className="text-slate-800">
              Control the Champions League draw process
            </CardDescription>
          </CardHeader>
          <CardContent className="pt-6">
            <div className="space-y-6">
              <div className="text-center">
                <Button
                  onClick={drawComplete ? handleStartDraw : handleSelectTeam}
                  disabled={currentStep !== "selectTeam" && !drawComplete}
                  className="w-full bg-[#0e1e5b] hover:bg-[#1e3a8a] text-white"
                >
                  {drawComplete ? (
                    <>
                      <Trophy className="mr-2 h-4 w-4" /> Start New Draw
                    </>
                  ) : currentStep === "selectTeam" ? (
                    <>
                      <Dices className="mr-2 h-4 w-4" /> Draw Next Team
                    </>
                  ) : (
                    <>
                      <Clock className="mr-2 h-4 w-4 animate-spin" />{" "}
                      Processing...
                    </>
                  )}
                </Button>
              </div>

              {currentTeam && (
                <div className="mt-4 p-4 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-700">
                  <div className="flex items-center justify-center space-x-2 mb-3">
                    <Shield className="h-5 w-5 text-[#0e1e5b] dark:text-[#3b82f6]" />
                    <h4 className="font-semibold text-center">Current Draw</h4>
                  </div>

                  <div className="flex items-center justify-center space-x-4 mb-3">
                    <Badge className={`${getPotColor(currentPot)} text-white`}>
                      Pot {currentPot}
                    </Badge>
                    <Badge variant="outline" className="text-sm font-normal">
                      {currentTeam}
                    </Badge>
                  </div>

                  {currentStep === "showOpponents" && (
                    <div className="mt-4 space-y-3">
                      <div className="flex items-center space-x-2">
                        <BarChart4 className="h-4 w-4 text-[#0e1e5b] dark:text-[#3b82f6]" />
                        <p className="font-medium">Admissible Opponents:</p>
                      </div>
                      <div className="bg-white dark:bg-slate-900 rounded-md border border-slate-200 dark:border-slate-700 p-2">
                        <ul className="text-sm space-y-1 max-h-40 overflow-y-auto">
                          {admissibleOpponents.map((opponent) => (
                            <li
                              key={opponent}
                              className="px-2 py-1.5 bg-slate-50 dark:bg-slate-800 rounded-md flex items-center"
                            >
                              <Shield className="h-3.5 w-3.5 mr-2 text-slate-400" />
                              {opponent}
                            </li>
                          ))}
                        </ul>
                      </div>
                      <Button
                        onClick={handleDrawOpponents}
                        className="w-full mt-4 bg-[#cfa749] hover:bg-[#ddb85a] text-[#0e1e5b]"
                        size="sm"
                      >
                        <Dices className="mr-2 h-4 w-4" /> Draw Opponents
                      </Button>
                    </div>
                  )}

                  {currentStep === "drawOpponents" && (
                    <div className="mt-4 space-y-3">
                      <div className="flex items-center space-x-2">
                        <Trophy className="h-4 w-4 text-[#cfa749]" />
                        <p className="font-medium">Selected Opponents:</p>
                      </div>
                      <div className="grid grid-cols-2 gap-2 text-sm">
                        <div className="p-2 bg-white dark:bg-slate-900 rounded-md border border-slate-200 dark:border-slate-700 flex items-center">
                          <Home className="h-3.5 w-3.5 mr-2 text-[#0e1e5b] dark:text-[#3b82f6]" />
                          <span className="font-medium mr-1">Home:</span>{" "}
                          <span className="truncate">
                            {selectedOpponents.home}
                          </span>
                        </div>
                        <div className="p-2 bg-white dark:bg-slate-900 rounded-md border border-slate-200 dark:border-slate-700 flex items-center">
                          <ExternalLink className="h-3.5 w-3.5 mr-2 text-[#0e1e5b] dark:text-[#3b82f6]" />
                          <span className="font-medium mr-1">Away:</span>{" "}
                          <span className="truncate">
                            {selectedOpponents.away}
                          </span>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              )}

              <Separator />

              <div className="mt-4">
                <div className="flex items-center space-x-2 mb-3">
                  <BarChart4 className="h-5 w-5 text-[#0e1e5b] dark:text-[#3b82f6]" />
                  <h4 className="font-semibold">Draw Progress</h4>
                </div>
                <div className="space-y-3">
                  {[1, 2, 3, 4].map((pot) => (
                    <div key={pot} className="space-y-1">
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-medium">Pot {pot}</span>
                        <span className="text-sm text-slate-500">
                          {potProgress[pot]}/9
                        </span>
                      </div>
                      <Progress
                        value={(potProgress[pot] / 9) * 100}
                        className="h-2"
                        indicatorClassName={getPotColor(pot)}
                      />
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Draw Results */}
        <Card className="md:col-span-2 border border-slate-200 dark:border-slate-800 shadow-md overflow-hidden">
          <CardHeader className="pb-4">
            <div className="flex items-center space-x-2">
              <Trophy className="h-5 w-5" />
              <CardTitle className="text-lg font-bold text-[#0e1e5b]">
                Draw Results
              </CardTitle>
            </div>
            <CardDescription className="text-slate-800">
              View the Champions League matchups
            </CardDescription>
          </CardHeader>
          <CardContent className="pt-6">
            <Tabs
              defaultValue="pot1"
              value={activeTab}
              onValueChange={setActiveTab}
              className="w-full"
            >
              <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-4">
                <TabsList className="bg-slate-100 dark:bg-slate-800 p-1">
                  <TabsTrigger
                    value="pot1"
                    className="data-[state=active]:bg-[#0e1e5b] data-[state=active]:text-white"
                  >
                    Pot 1
                  </TabsTrigger>
                  <TabsTrigger
                    value="pot2"
                    className="data-[state=active]:bg-[#1e3a8a] data-[state=active]:text-white"
                  >
                    Pot 2
                  </TabsTrigger>
                  <TabsTrigger
                    value="pot3"
                    className="data-[state=active]:bg-[#2563eb] data-[state=active]:text-white"
                  >
                    Pot 3
                  </TabsTrigger>
                  <TabsTrigger
                    value="pot4"
                    className="data-[state=active]:bg-[#3b82f6] data-[state=active]:text-white"
                  >
                    Pot 4
                  </TabsTrigger>
                </TabsList>
              </div>

              {drawComplete ? (
                <Alert className="mb-4 border-[#cfa749] bg-[#cfa749]/10">
                  <Trophy className="h-4 w-4 text-[#cfa749]" />
                  <AlertTitle className="text-[#cfa749]">
                    Draw Complete!
                  </AlertTitle>
                  <AlertDescription>
                    The Champions League draw has been completed successfully.
                  </AlertDescription>
                </Alert>
              ) : (
                <Alert className="mb-4 border-[#0e1e5b] bg-[#0e1e5b]/10">
                  <AlertCircle className="h-4 w-4 text-[#0e1e5b] dark:text-[#3b82f6]" />
                  <AlertTitle className="text-[#0e1e5b] dark:text-[#3b82f6]">
                    Draw in Progress
                  </AlertTitle>
                  <AlertDescription>
                    {currentPot === 1
                      ? "Drawing opponents for Pot 1 teams"
                      : `Pot ${
                          currentPot - 1
                        } complete. Drawing opponents for Pot ${currentPot} teams`}
                  </AlertDescription>
                </Alert>
              )}

              {["pot1", "pot2", "pot3", "pot4"].map((pot, index) => (
                <TabsContent key={pot} value={pot} className="m-0">
                  <div className="overflow-x-auto rounded-md border border-slate-200 dark:border-slate-800">
                    <div className="max-h-[420px] overflow-y-auto">
                      <table className="w-full border-collapse">
                        <thead>
                          <tr className="bg-slate-100 dark:bg-slate-800">
                            <th className="px-4 py-1.5 text-left font-semibold whitespace-nowrap">
                              Team
                            </th>
                            <th
                              colSpan={2}
                              className="px-2 py-1.5 text-center font-semibold"
                            >
                              <div className="flex items-center justify-center space-x-2">
                                <Badge className="bg-[#0e1e5b] text-white text-xs py-0 h-5">
                                  Pot 1
                                </Badge>
                              </div>
                            </th>
                            <th
                              colSpan={2}
                              className="px-2 py-1.5 text-center font-semibold"
                            >
                              <div className="flex items-center justify-center space-x-2">
                                <Badge className="bg-[#1e3a8a] text-white text-xs py-0 h-5">
                                  Pot 2
                                </Badge>
                              </div>
                            </th>
                            <th
                              colSpan={2}
                              className="px-2 py-1.5 text-center font-semibold"
                            >
                              <div className="flex items-center justify-center space-x-2">
                                <Badge className="bg-[#2563eb] text-white text-xs py-0 h-5">
                                  Pot 3
                                </Badge>
                              </div>
                            </th>
                            <th
                              colSpan={2}
                              className="px-2 py-1.5 text-center font-semibold"
                            >
                              <div className="flex items-center justify-center space-x-2">
                                <Badge className="bg-[#3b82f6] text-white text-xs py-0 h-5">
                                  Pot 4
                                </Badge>
                              </div>
                            </th>
                          </tr>
                          <tr className="bg-slate-50 dark:bg-slate-900 h-7">
                            <th className="px-4 py-0.5"></th>
                            <th className="px-2 py-0.5 text-center text-xs font-medium text-slate-500">
                              <div className="flex items-center justify-center">
                                <Home className="h-3 w-3 mr-1" /> Home
                              </div>
                            </th>
                            <th className="px-2 py-0.5 text-center text-xs font-medium text-slate-500">
                              <div className="flex items-center justify-center">
                                <ExternalLink className="h-3 w-3 mr-1" /> Away
                              </div>
                            </th>
                            <th className="px-2 py-0.5 text-center text-xs font-medium text-slate-500">
                              <div className="flex items-center justify-center">
                                <Home className="h-3 w-3 mr-1" /> Home
                              </div>
                            </th>
                            <th className="px-2 py-0.5 text-center text-xs font-medium text-slate-500">
                              <div className="flex items-center justify-center">
                                <ExternalLink className="h-3 w-3 mr-1" /> Away
                              </div>
                            </th>
                            <th className="px-2 py-0.5 text-center text-xs font-medium text-slate-500">
                              <div className="flex items-center justify-center">
                                <Home className="h-3 w-3 mr-1" /> Home
                              </div>
                            </th>
                            <th className="px-2 py-0.5 text-center text-xs font-medium text-slate-500">
                              <div className="flex items-center justify-center">
                                <ExternalLink className="h-3 w-3 mr-1" /> Away
                              </div>
                            </th>
                            <th className="px-2 py-0.5 text-center text-xs font-medium text-slate-500">
                              <div className="flex items-center justify-center">
                                <Home className="h-3 w-3 mr-1" /> Home
                              </div>
                            </th>
                            <th className="px-2 py-0.5 text-center text-xs font-medium text-slate-500">
                              <div className="flex items-center justify-center">
                                <ExternalLink className="h-3 w-3 mr-1" /> Away
                              </div>
                            </th>
                          </tr>
                        </thead>
                        <tbody>
                          {TEAMS_DATA[pot as keyof typeof TEAMS_DATA].map(
                            (team) => renderTeamOpponents(team)
                          )}
                        </tbody>
                      </table>
                    </div>
                  </div>
                </TabsContent>
              ))}
            </Tabs>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
