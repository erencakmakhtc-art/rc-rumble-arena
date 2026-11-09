"""Source-level regression checks for the RC Rumble Three.js game."""

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
WEB_GAME = ROOT / "web" / "domino.html"
MOBILE_GAME = ROOT / "assets" / "games" / "domino_bayrak.html"
SOURCE = WEB_GAME.read_text(encoding="utf-8")


def section(start: str, end: str) -> str:
    first = SOURCE.index(start)
    return SOURCE[first : SOURCE.index(end, first)]


class RcRumbleRegressionTests(unittest.TestCase):
    def test_mobile_and_browser_use_identical_game_files(self):
        self.assertEqual(WEB_GAME.read_bytes(), MOBILE_GAME.read_bytes())

    def test_domino_gameplay_is_removed(self):
        self.assertNotIn("startCascadeFrom", SOURCE)
        self.assertNotIn("DOMINO", SOURCE)
        self.assertIn("<h1>RC <span>RUMBLE</span></h1>", SOURCE)

    def test_three_selectable_vehicles_have_distinct_mass_speed_and_ram(self):
        self.assertIn("sprinter:{name:'SPRINTER'", SOURCE)
        self.assertIn("bulldog:{name:'BULLDOG'", SOURCE)
        self.assertIn("rally:{name:'RALLY'", SOURCE)
        specs = re.findall(r"(sprinter|bulldog|rally):\{[^}]+\}", SOURCE)
        self.assertEqual(set(specs), {"sprinter", "bulldog", "rally"})
        sprinter = re.search(r"sprinter:\{([^}]+)\}", SOURCE).group(1)
        bulldog = re.search(r"bulldog:\{([^}]+)\}", SOURCE).group(1)
        self.assertIn("maxSpeed:16.5", sprinter)
        self.assertIn("mass:0.82", sprinter)
        self.assertIn("mass:1.72", bulldog)
        self.assertIn("ram:1.34", bulldog)

    def test_each_vehicle_has_its_own_special_ability(self):
        sprinter = re.search(r"sprinter:\{([^}]+)\}", SOURCE).group(1)
        bulldog = re.search(r"bulldog:\{([^}]+)\}", SOURCE).group(1)
        rally = re.search(r"rally:\{([^}]+)\}", SOURCE).group(1)
        self.assertIn("ability:'jump'", sprinter)
        self.assertIn("ability:'shockwave'", bulldog)
        self.assertIn("ability:'turbo'", rally)
        self.assertEqual(SOURCE.count("abilityCooldown:10"), 3)
        self.assertIn("turboDuration:2.5", rally)
        ability = section("function activateAbility(", "function updateShockwaves(")
        self.assertIn("car.jumpVelocity=9.4", ability)
        self.assertIn("const radius=7.2", ability)
        self.assertIn("target.vx+=nx*impulse/target.spec.mass", ability)
        self.assertIn("car.turboTime=car.spec.turboDuration", ability)
        self.assertIn("car.spec.ability==='turbo'&&car.turboTime>0", section("function updateCar(", "function resolveCarCollisions("))
        self.assertIn("specialCooldown.toFixed(1)", SOURCE)

    def test_special_ability_button_adapts_to_the_selected_vehicle(self):
        self.assertIn("buttonLabels={jump:'ZIPLA',shockwave:'ŞOK',turbo:'TURBO'}", SOURCE)
        self.assertIn("ui.abilityButtonLabel.textContent=buttonLabels[spec.ability]", SOURCE)
        self.assertIn("abilityPressed=true", SOURCE)

    def test_vehicle_cards_select_the_player_car_and_leave_two_rivals(self):
        self.assertEqual(SOURCE.count('data-type="sprinter"') + SOURCE.count('data-type="bulldog"') + SOURCE.count('data-type="rally"'), 3)
        self.assertIn("selectedCards.forEach(card=>card.addEventListener('click'", SOURCE)
        self.assertIn("makeCar(selectedType,'player',0,0,0,Math.PI/2)", SOURCE)
        self.assertIn("filter(t=>t!==selectedType)", SOURCE)
        self.assertEqual(SOURCE.count("makeCar(rivals["), 2)

    def test_vehicle_motion_uses_forward_throttle_steering_and_boost(self):
        movement = section("function updateCar(", "function resolveCarCollisions(")
        self.assertIn("car.spec.accel*input.throttle", movement)
        self.assertIn("car.spec.turn*turnFactor", movement)
        self.assertIn("car.spec.turboMultiplier*input.throttle*dt", movement)
        self.assertIn("car.turboTime=Math.max(0,car.turboTime-dt)", movement)
        self.assertIn("Math.exp(-car.spec.grip*dt)", movement)

    def test_impacts_use_relative_velocity_and_mass(self):
        collisions = section("function resolveCarCollisions(", "const sparkGeometry")
        self.assertIn("CAR_RADIUS*2", collisions)
        self.assertIn("1/a.spec.mass", collisions)
        self.assertIn("1/b.spec.mass", collisions)
        self.assertIn("const rel=(b.vx-a.vx)*nx+(b.vz-a.vz)*nz", collisions)
        self.assertIn("-(1+.48)*rel/invSum*(.72+ram*.28)*1.04", collisions)
        self.assertIn("a.spec.ram*approachA+b.spec.ram*approachB", collisions)

    def test_out_of_bounds_eliminates_cars_and_match_has_clear_end_conditions(self):
        self.assertIn("const ARENA_RADIUS=22.5, CAR_RADIUS=1.27, ELIMINATION_MARGIN=1.55", SOURCE)
        self.assertIn("ELIMINATION_MARGIN=1.55", SOURCE)
        self.assertIn("if(radial>activeArenaRadius+ELIMINATION_MARGIN)", SOURCE)
        self.assertIn("if(enemyCount()===0)endRound(true", SOURCE)
        self.assertIn("if(roundLeft<=0&&gameState==='playing')", SOURCE)
        self.assertIn("const won=player&&!player.eliminated&&survivors.length===1", SOURCE)

    def test_team_modes_offer_two_and_three_per_side(self):
        self.assertIn('data-mode="2v2"', SOURCE)
        self.assertIn('data-mode="3v3"', SOURCE)
        self.assertIn("'2v2':{teamSize:2}", SOURCE)
        self.assertIn("'3v3':{teamSize:3}", SOURCE)
        self.assertIn("makeCar(homeRoster[i],i===0?'player':'ally',0", SOURCE)
        self.assertIn("makeCar(awayRoster[i],'ai',1", SOURCE)
        self.assertIn("teamBattle?MODES[selectedMode].teamSize:2", SOURCE)

    def test_team_ai_fights_the_opposing_team_and_teammates_do_not_ram(self):
        ai = section("function aiInput(", "function angleDelta(")
        self.assertIn("!teamBattle||c.team!==car.team", ai)
        collisions = section("function resolveCarCollisions(", "const sparkGeometry")
        self.assertIn("sameTeam=teamBattle&&a.team===b.team", collisions)
        self.assertIn("if(rel<0&&!sameTeam)", collisions)
        self.assertIn("safeTeamSeparation", collisions)

    def test_ai_varies_targets_and_does_not_permanently_chase_the_player(self):
        ai = section("function aiInput(", "function angleDelta(")
        self.assertIn("Math.random()<.55", ai)
        self.assertIn("aiBehavior=Math.random()<.22?'patrol':'attack'", ai)
        self.assertIn("aiTarget=scored[0]?.candidate", ai)

    def test_arena_starts_shrinking_after_25_seconds(self):
        self.assertIn("SHRINK_START_SECONDS=25", SOURCE)
        self.assertIn("FINAL_ARENA_RADIUS=13.5", SOURCE)
        self.assertIn("lerp(ARENA_RADIUS,FINAL_ARENA_RADIUS,progress)", SOURCE)
        self.assertIn("if(progress>0&&!shrinkStarted)", SOURCE)
        self.assertIn("updateArenaShrink()", SOURCE)
        self.assertIn("platformFloor.scale.set(scale,scale,1)", SOURCE)
        self.assertIn("platformBase.scale.set(scale,1,scale)", SOURCE)
        self.assertIn("if(arenaRim)arenaRim.scale.set(scale,1,scale)", SOURCE)
        self.assertIn("if(arenaRimTop)arenaRimTop.scale.set(scale,scale,1)", SOURCE)

    def test_arena_has_a_low_lip_spectators_and_brighter_lighting(self):
        self.assertIn("new THREE.CylinderGeometry(ARENA_RADIUS+.12,ARENA_RADIUS+.12,.3,160,1,true)", SOURCE)
        self.assertIn("const peoplePerTier=160,tierCount=10", SOURCE)
        self.assertIn("ARENA_RADIUS+5.15+tier*.72", SOURCE)
        self.assertIn("baseY=.28+tier*.72", SOURCE)
        self.assertIn("new THREE.InstancedMesh(bodyGeo,crowdMat,peopleCount)", SOURCE)
        self.assertIn("new THREE.SpotLight(0xffefda,115", SOURCE)
        self.assertNotIn("arenaRopes", SOURCE)
        self.assertNotIn("TorusGeometry(ARENA_RADIUS+.3,.075", SOURCE)
        self.assertIn("if(entranceAngles.some(g=>Math.abs(Math.atan2(Math.sin(angle-g),Math.cos(angle-g)))<.075))continue", SOURCE)
        self.assertIn("step=new THREE.Mesh(new THREE.BoxGeometry(4.35,.12,.78)", SOURCE)
        self.assertIn("audienceFlashTimer=2.5+Math.random()*7.5", SOURCE)
        self.assertIn("flash.light.intensity=260*Math.sin(Math.PI*phase)", SOURCE)
        self.assertIn("updateAudienceFlashes(dt)", SOURCE)

    def test_contact_separation_reduces_vehicle_jams(self):
        collisions = section("function resolveCarCollisions(", "const sparkGeometry")
        self.assertIn("correction=Math.max(0,overlap-.008)*.9", collisions)
        self.assertIn("if(rel<0&&!sameTeam)", collisions)
        self.assertIn("a.decision=Math.min(a.decision,.45)", collisions)
        self.assertIn("if(wheelOverhang>0&&radial>activeArenaRadius)", SOURCE)
        self.assertIn("curbResistance=.18+leanRatio*.22", SOURCE)
        self.assertIn("curbResistance*dt", SOURCE)

    def test_cars_lean_towards_the_edge_before_falling(self):
        movement = section("function updateCar(", "function resolveCarCollisions(")
        self.assertIn("wheelOverhang=radial+CAR_RADIUS-activeArenaRadius", movement)
        self.assertIn("edgePitch=outwardForward*edgeLean,edgeRoll=-outwardSide*edgeLean", movement)
        self.assertIn("car.mesh.rotation.x+=(edgePitch-car.mesh.rotation.x)*settle", movement)
        self.assertIn("car.mesh.rotation.z+=(edgeRoll+skidRoll-car.mesh.rotation.z)*settle", movement)

    def test_player_elimination_keeps_the_team_round_alive_for_allies(self):
        elimination = section("function eliminate(", "function updateCamera(")
        self.assertIn("else if(car===player){showEvent", elimination)
        self.assertIn("Takım arkadaşların savaşa devam ediyor", elimination)
        self.assertIn("function checkTeamOutcome()", SOURCE)
        self.assertIn("teamBattle?cars.find(c=>c.team===0&&!c.eliminated&&!c.falling):null", SOURCE)

    def test_team_result_uses_surviving_team_counts_and_can_draw(self):
        self.assertIn("function activeTeamCount(team)", SOURCE)
        self.assertIn("if(activeTeamCount(0)===0)endRound(false", SOURCE)
        self.assertIn("else if(activeTeamCount(1)===0)endRound(true", SOURCE)
        self.assertIn("const own=activeTeamCount(0),enemy=activeTeamCount(1),draw=own===enemy", SOURCE)
        self.assertIn("endRound(won,draw?", SOURCE)

    def test_keyboard_and_touch_controls_include_boost(self):
        self.assertIn("window.addEventListener('keydown'", SOURCE)
        self.assertIn("window.addEventListener('keyup'", SOURCE)
        self.assertIn("stick.addEventListener('pointerdown'", SOURCE)
        self.assertIn("stick.addEventListener('pointermove'", SOURCE)
        self.assertIn("boostButton.addEventListener('pointerdown'", SOURCE)
        self.assertIn("key===' '&&!keys[key])abilityPressed=true", SOURCE)

    def test_right_and_left_steering_match_their_controls(self):
        controls = section("function readInput(", "function aiInput(")
        self.assertIn("const steer=(keys.a||keys.ArrowLeft?1:0)-(keys.d||keys.ArrowRight?1:0)", controls)
        self.assertIn("steer:-stickState.x", controls)

    def test_all_gameplay_dom_references_have_a_matching_element(self):
        ids = set(re.findall(r'\bid="([^"]+)"', SOURCE))
        references = set(re.findall(r"getElementById\('([^']+)'\)", SOURCE))
        self.assertTrue(references)
        self.assertEqual(references - ids, set())


if __name__ == "__main__":
    unittest.main(verbosity=2)
