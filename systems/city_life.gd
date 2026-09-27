extends Node3D

# Repeated street geometry is instanced per 80m cell. Pedestrians share a small
# set of meshes/materials; only nearby walkers receive full-rate limb animation.
const CROWD_TARGET = 280
const CELL_SIZE = 80.0
const SHIRTS = [Color("d7714d"), Color("4e8f9a"), Color("c8ad61"), Color("7b6ea1"), Color("e1d3b4"), Color("3b536b")]
const SKINS = [Color("c99573"), Color("704b3c"), Color("e3b894"), Color("ab7552")]
var walkers: Array[Dictionary] = []
var route_members: Dictionary = {}
var routes: Array[PackedVector3Array] = []
var footprints: Array[Rect2] = []
var batches: Dictionary = {}
var crowd_meshes: Dictionary = {}
var static_instance_count = 0
var elapsed = 0.0
var active_walkers = 0
var player: Node3D
var rng = RandomNumberGenerator.new()
var box_mesh = BoxMesh.new()
var sphere_mesh = SphereMesh.new()
var cylinder_mesh = CylinderMesh.new()
var shared_material = StandardMaterial3D.new()
var citizen_body = CylinderMesh.new()
var solid_props = 0

func setup(city: Node3D):
    name = "CityLife"
    rng.seed = 783402
    box_mesh.size = Vector3.ONE
    sphere_mesh.radius = 1.0
    sphere_mesh.height = 2.0
    sphere_mesh.radial_segments = 8
    sphere_mesh.rings = 4
    cylinder_mesh.top_radius = .5
    cylinder_mesh.bottom_radius = .5
    cylinder_mesh.height = 1.0
    cylinder_mesh.radial_segments = 8
    citizen_body.top_radius = .5
    citizen_body.bottom_radius = .38
    citizen_body.height = 1.0
    citizen_body.radial_segments = 8
    citizen_body.rings = 2
    shared_material.vertex_color_use_as_albedo = true
    shared_material.roughness = .9
    for building in get_tree().get_nodes_in_group("city_building"):
        var shape = building.get_node_or_null("CollisionShape3D")
        # Existing builder leaves unnamed CollisionShape3D children.
        if shape == null:
            for child in building.get_children():
                if child is CollisionShape3D:
                    shape = child
                    break
        if shape != null and shape.shape is BoxShape3D:
            var size: Vector3 = shape.shape.size
            if absf(building.rotation.y) > .1:
                size = Vector3(size.z, size.y, size.x)
            footprints.append(Rect2(Vector2(building.position.x - size.x / 2, building.position.z - size.z / 2), Vector2(size.x, size.z)))
            _shopfront(building, shape.shape.size)
    var blocks: Array = city._city_block_rects()
    for index in blocks.size():
        var block: Rect2 = blocks[index]
        _sidewalk(block)
        var walk_rect = block.grow(1.25)
        var points = PackedVector3Array([
            Vector3(walk_rect.position.x, .14, walk_rect.position.y),
            Vector3(walk_rect.end.x, .14, walk_rect.position.y),
            Vector3(walk_rect.end.x, .14, walk_rect.end.y),
            Vector3(walk_rect.position.x, .14, walk_rect.end.y)])
        if _route_clear(points):
            routes.append(points)
        _street_furniture(block, index)
        if index % 7 == 0:
            _bus_stop(block,index)
        if index % 12 == 11:
            await get_tree().process_frame
    _crosswalks(city)
    _flush_batches()
    _build_crowd()
    print("[CITY LIFE] ", static_instance_count, " detail instances / ", batches.size(), " batches; ", walkers.size(), " pedestrians / ", routes.size(), " clear sidewalk loops")

func _clear(point: Vector2, radius = .8) -> bool:
    for rect in footprints:
        if rect.grow(radius).has_point(point):
            return false
    return true

func _route_clear(points: PackedVector3Array) -> bool:
    for i in points.size():
        var a = points[i]
        var b = points[(i + 1) % points.size()]
        var steps = maxi(1, ceili(a.distance_to(b) / 1.0))
        for step in steps + 1:
            var p = a.lerp(b, float(step) / steps)
            if not _clear(Vector2(p.x, p.z), .38):
                return false
    return true

func _sidewalk(block: Rect2):
    var center = block.get_center()
    var pavement = Color("879293")
    var curb = Color("aeb7b1")
    for z in [block.position.y - 1.3, block.end.y + 1.3]:
        _part("box", Vector3(center.x, .06, z), Vector3(block.size.x + 5.2, .12, 2.6), pavement)
        _part("box", Vector3(center.x, .12, z + (-1.2 if z < center.y else 1.2)), Vector3(block.size.x + 5.2, .13, .12), curb)
        for x in range(ceili(block.position.x), floori(block.end.x), 4):
            _part("box", Vector3(x, .125, z), Vector3(.025, .01, 2.5), Color("667477"))
    for x in [block.position.x - 1.3, block.end.x + 1.3]:
        _part("box", Vector3(x, .06, center.y), Vector3(2.6, .12, block.size.y), pavement)
        _part("box", Vector3(x + (-1.2 if x < center.x else 1.2), .12, center.y), Vector3(.12, .13, block.size.y), curb)

func _street_furniture(block: Rect2, index: int):
    var z = block.position.y + 1.5
    for x in range(ceili(block.position.x + 7), floori(block.end.x - 5), 14):
        if not _clear(Vector2(x, z), 2.0):
            continue
        var p = Vector3(x, 0, z)
        _solid_box(p + Vector3(0,1.6,0),Vector3(.4,3.2,.4))
        # Planter, trunk and three distinct foliage masses.
        _part("box", p + Vector3(0,.23,0), Vector3(2.4,.46,2.4), Color("4b585e"))
        _part("cylinder", p + Vector3(0,1.7,0), Vector3(.26,3.1,.26), Color("665144"))
        _part("sphere", p + Vector3(0,3.5,0), Vector3(1.45,1.6,1.35), Color("537e64"))
        _part("sphere", p + Vector3(.7,3.1,.25), Vector3(.9,1.05,.9), Color("6c916a"))
        _part("sphere", p + Vector3(-.65,3.35,-.2), Vector3(.95,1.2,.8), Color("436c5a"))
        var seat = p + Vector3(4,0,0)
        if _clear(Vector2(seat.x, seat.z), 1.6):
            for dz in [-.27,0,.27]:
                _part("box", seat + Vector3(0,.57,dz), Vector3(2.25,.10,.21), Color("9d795a"))
            _part("box", seat + Vector3(0,1.05,.38), Vector3(2.25,.6,.1), Color("9d795a"))
            for dx in [-.85,.85]:
                _part("box", seat + Vector3(dx,.3,0), Vector3(.12,.6,.65), Color("293945"))
            _part("cylinder", seat + Vector3(1.9,.5,0), Vector3(.55,1,.55), Color("385461"))
    var lamp = Vector3(block.position.x + 1.5, 0, block.end.y - 5)
    if _clear(Vector2(lamp.x,lamp.z), .5):
        _part("cylinder", lamp + Vector3(0,3.3,0), Vector3(.16,6.6,.16), Color("34434c"))
        _part("box", lamp + Vector3(0,6.5,-.6), Vector3(.18,.15,1.3), Color("34434c"))
        _part("box", lamp + Vector3(0,6.4,-1.1), Vector3(.65,.15,.65), Color("ffe0a1"))
    # Parked cars sit in setbacks, outside the pedestrian lane and travel lanes.
    var parked = Vector3(block.end.x - 3, 0, block.end.y - 3)
    if index % 3 == 0 and _clear(Vector2(parked.x,parked.z), 2.5):
        _car(parked, SHIRTS[index % SHIRTS.size()])

func _car(p: Vector3, color: Color):
    _solid_box(p + Vector3(0,.8,0),Vector3(1.8,1.6,3.8))
    _part("box", p + Vector3(0,.65,0), Vector3(1.8,.7,3.8), color)
    _part("box", p + Vector3(0,1.2,-.2), Vector3(1.55,.65,2), Color("263d4a"))
    _part("box", p + Vector3(0,1.58,-.2), Vector3(1.6,.1,2.1), color)
    for x in [-.87,.87]:
        for z in [-1.15,1.15]:
            _part("sphere", p + Vector3(x,.38,z), Vector3(.19,.37,.37), Color("20272d"))
    for x in [-.6,.6]:
        _part("box", p + Vector3(x,.72,-1.92), Vector3(.38,.18,.03), Color("ffe6b7"))
        _part("box", p + Vector3(x,.72,1.92), Vector3(.38,.16,.03), Color("ca5850"))

func _shopfront(building: Node3D, size: Vector3):
    var base_y = -size.y / 2
    var accent = SHIRTS[rng.randi_range(0,SHIRTS.size()-1)]
    # Ground-floor storefronts on two faces. Geometry uses building transform.
    for face in 2:
        var yaw = face * PI
        var basis = Basis(Vector3.UP, yaw)
        var front = size.z / 2 + .2
        for x in [-size.x*.28, size.x*.28]:
            var transform = building.global_transform * Transform3D(basis, Vector3.ZERO)
            _part("box", transform * Vector3(x,base_y+1.5,front), Vector3(size.x*.34,2.65,.13), Color("253d4e"), transform.basis)
            _part("box", transform * Vector3(x,base_y+3.1,front+.48), Vector3(size.x*.39,.20,1.15), accent, transform.basis)
            _part("box", transform * Vector3(x,base_y+3.5,front), Vector3(size.x*.38,.58,.18), accent.darkened(.35), transform.basis)
            for stripe in [-.12,.0,.12]:
                _part("box", transform * Vector3(x+size.x*stripe,base_y+1.45,front+.1), Vector3(.08,2.5,.10), Color("9bafb1"), transform.basis)
        _part("box", building.to_global(basis * Vector3(0,base_y+1.35,front)), Vector3(1.2,2.7,.2), Color("172a37"), building.global_basis * basis)
    if rng.randf() < .32:
        var sign = Label3D.new()
        sign.text = ["POLET / RECORDS", "KUTAK CAFE", "STUDIO 23", "NOĆNI MARKET", "RADIO MDK", "BLOK / BAKERY"][rng.randi_range(0,5)]
        sign.font_size = 42
        sign.outline_size = 4
        sign.pixel_size = minf(.013,size.x*.32/300)
        sign.position = Vector3(-size.x*.28,base_y+3.5,size.z/2+.32)
        sign.modulate = Color("f4ddab")
        sign.visibility_range_end = 100
        building.add_child(sign)
    # Sparse fire-escape balconies add depth without filling every facade.
    if rng.randf() < .18 and size.y > 22:
        for floor_y in range(7,mini(int(size.y)-3,34),5):
            var t = building.global_transform
            var x = size.x*.26
            var z = size.z/2+.9
            _part("box",t*Vector3(x,base_y+floor_y,z),Vector3(3,.12,1.5),Color("34414a"),t.basis)
            _part("box",t*Vector3(x,base_y+floor_y+1,z+.7),Vector3(3,.07,.07),Color("34414a"),t.basis)
            for dx in [-1.4,0,1.4]:
                _part("box",t*Vector3(x+dx,base_y+floor_y+.5,z+.7),Vector3(.06,1,.06),Color("34414a"),t.basis)
            for step in 8:
                _part("box",t*Vector3(x+1.25,base_y+floor_y-step*.625,z),Vector3(.7,.08,.16),Color("52616b"),t.basis)
    # Raised cornices and masonry piers catch sunlight and cast real shadows.
    var trim = Color("aca38e")
    var levels = [base_y + 4.1, size.y / 2 - .3]
    if size.y > 30:
        levels.append(base_y + size.y * .52)
    for y in levels:
        for side in [-1,1]:
            _part("box", building.to_global(Vector3(0,y,side*(size.z/2+.22))), Vector3(size.x+.5,.24,.44),trim,building.global_basis)
            _part("box", building.to_global(Vector3(side*(size.x/2+.22),y,0)), Vector3(.44,.24,size.z+.5),trim,building.global_basis)
    for x in [-size.x/2+.14,size.x/2-.14]:
        for z in [-size.z/2-.17,size.z/2+.17]:
            _part("box",building.to_global(Vector3(x,0,z)),Vector3(.34,size.y,.3),trim.darkened(.18),building.global_basis)
    # Roof parapets leave the front edge clear for landing, plus solar panels.
    var top = size.y / 2
    for side in [-1,1]:
        _part("box", building.to_global(Vector3(side*(size.x/2-.12),top+.35,0)), Vector3(.24,.7,size.z), Color("68777e"), building.global_basis)
    if rng.randf() < .55:
        for i in 3:
            var pos = building.to_global(Vector3(size.x*.18,top+.55,-size.z*.2+i*1.6))
            _part("box", pos, Vector3(3.2,.12,1.25), Color("254c69"), building.global_basis * Basis(Vector3.RIGHT,-.24))

func _crosswalks(city):
    for x in city.CITY_ROADS_X:
        for z in city.CITY_ROADS_Z:
            for side in [-1,1]:
                var crossing_z = z + side * (city._road_width(z)/2 + 2)
                for dx in range(-int(city._road_width(x)/2)+1, int(city._road_width(x)/2), 2):
                    var p = Vector3(x+dx,.135,crossing_z)
                    if _clear(Vector2(p.x,p.z), .8):
                        _part("box", p, Vector3(.8,.02,2.6), Color("d2d2ba"))

func _part(kind: String, pos: Vector3, size: Vector3, color: Color, rotation_basis = Basis.IDENTITY):
    var cell = Vector2i(floori(pos.x/CELL_SIZE), floori(pos.z/CELL_SIZE))
    var key = "%d:%d:%s" % [cell.x,cell.y,kind]
    if not batches.has(key):
        batches[key] = {"kind":kind,"transforms":[],"colors":[],"origin":Vector3(cell.x*CELL_SIZE,0,cell.y*CELL_SIZE)}
    batches[key].transforms.append(Transform3D(rotation_basis * Basis.from_scale(size),pos-batches[key].origin))
    batches[key].colors.append(color)
    static_instance_count += 1

func _flush_batches():
    for key in batches:
        var data = batches[key]
        var instance = MultiMeshInstance3D.new()
        instance.name = "Detail_" + key.replace(":", "_")
        var mm = MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.use_colors = true
        mm.mesh = {"box":box_mesh,"sphere":sphere_mesh,"cylinder":cylinder_mesh}[data.kind]
        mm.instance_count = data.transforms.size()
        for i in mm.instance_count:
            mm.set_instance_transform(i,data.transforms[i])
            mm.set_instance_color(i,data.colors[i])
        instance.multimesh = mm
        instance.position = data.origin
        instance.material_override = shared_material
        instance.visibility_range_end = 230.0
        instance.visibility_range_end_margin = 25.0
        add_child(instance)

func _build_crowd():
    if routes.is_empty():
        return
    for i in CROWD_TARGET:
        var route_index = i % routes.size()
        var route = routes[route_index]
        var length = 0.0
        for j in route.size():
            length += route[j].distance_to(route[(j+1)%route.size()])
        walkers.append({"route":route_index,"distance":rng.randf()*length,"length":length,"speed":rng.randf_range(.85,1.65),"phase":rng.randf()*TAU,"pause":rng.randf_range(0,5),"shirt":SHIRTS[i%SHIRTS.size()],"skin":SKINS[i%SKINS.size()],"position":Vector3.ZERO,"direction":Vector3.FORWARD,"was_visible":true,"motion":0.0,"height":.92+float(i%7)*.025,"build":.90+float(i%5)*.06})
        if not route_members.has(route_index):
            route_members[route_index] = []
        route_members[route_index].append(i)
    for part in ["body","head","hair","arms","forearms","legs","shins","shoes","hands","bag","neck","eyes","nose","collar","belt","hat","knees","elbows","ears","pockets","zipper","hood"]:
        var mm = MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.use_colors = true
        mm.mesh = sphere_mesh if part in ["head","hands","hair","knees","elbows","ears","hood"] else (citizen_body if part == "body" else (cylinder_mesh if part in ["arms","forearms","legs","shins"] else box_mesh))
        mm.instance_count = walkers.size() * (2 if part in ["arms","forearms","legs","shins","shoes","hands","eyes","knees","elbows","ears","pockets"] else 1)
        var instance = MultiMeshInstance3D.new()
        instance.name = "Crowd_" + part
        instance.multimesh = mm
        instance.material_override = shared_material
        add_child(instance)
        crowd_meshes[part] = mm
    _process(0)

func _process(delta):
    elapsed += delta
    if player == null:
        player = get_parent().get("player")
    active_walkers = 0
    var eye = player.global_position if is_instance_valid(player) else Vector3.ZERO
    for i in walkers.size():
        var person = walkers[i]
        var walking = fmod(elapsed + person.pause * 8, 29.0) > 2.0
        var previous: Vector3 = person.position
        # Stop rather than walking through the player; authored loops avoid buildings.
        var near_player = previous.distance_squared_to(eye) < 2.25
        var following = false
        for other_index in route_members[person.route]:
            if other_index == i:
                continue
            var gap = fposmod(walkers[other_index].distance-person.distance,person.length)
            if gap > .01 and gap < 1.2:
                following = true
                break
        var moving = walking and not near_player and not following
        person.motion = move_toward(person.motion, 1.0 if moving else 0.0, delta*4.0)
        if not near_player and not following:
            person.distance = fposmod(person.distance + delta * person.speed * person.motion,person.length)
        var route = routes[person.route]
        var remaining: float = person.distance
        for j in route.size():
            var a = route[j]
            var b = route[(j+1)%route.size()]
            var length = a.distance_to(b)
            if remaining <= length:
                person.position = a.lerp(b,remaining/length)
                person.direction = person.direction.lerp((b-a).normalized(),minf(1,delta*6)).normalized()
                break
            remaining -= length
        var visible_near = person.position.distance_squared_to(eye) < 190.0*190.0
        if visible_near:
            active_walkers += 1
        if not visible_near and not person.was_visible:
            continue
        person.was_visible = visible_near
        var gait = sin(person.distance * TAU / 1.2 + person.phase) * .48 * person.motion
        _draw_person(i,person,gait,visible_near)

func _draw_person(i: int, person: Dictionary, gait: float, show_person: bool):
    var scale_factor = person.height if show_person else 0.0001
    var facing = Basis.looking_at(person.direction,Vector3.UP).scaled(Vector3.ONE*scale_factor)
    var root_transform = Transform3D(facing,person.position)
    var cycle = person.distance * TAU / 1.2 + person.phase
    var bob = (cos(cycle*2.0)*.012) * person.motion
    var torso = root_transform * Transform3D(Basis(Vector3.FORWARD,gait*.035),Vector3(0,bob,0))
    var shirt: Color = person.shirt
    var skin: Color = person.skin
    var trousers = [Color("334355"),Color("655b50"),Color("293235"),Color("574b66")][i%4]
    var hair = [Color("342d2a"),Color("806345"),Color("221f25"),Color("aaa399")][i%4]
    var width: float = person.build
    _crowd_part("body",i,torso,Vector3(0,1.16,0),Vector3(.50*width,.55,.34),shirt)
    _crowd_part("belt",i,torso,Vector3(0,.89,0),Vector3(.37*width,.10,.28),trousers)
    _crowd_part("neck",i,torso,Vector3(0,1.49,0),Vector3(.14,.16,.14),skin)
    _crowd_part("collar",i,torso,Vector3(0,1.425,-.01),Vector3(.22,.06,.23),shirt.lightened(.20))
    _crowd_part("head",i,torso,Vector3(0,1.68,-.015),Vector3(.145,.19,.15),skin)
    _crowd_part("hair",i,torso,Vector3(0,1.80,.015),Vector3(.15,.095+float(i%3)*.025,.15),hair)
    _crowd_part("nose",i,torso,Vector3(0,1.68,-.16),Vector3(.046,.065,.045),skin.darkened(.06))
    _crowd_part("hat",i,torso,Vector3(0,1.83,-.04),Vector3(.32,.07,.38) if i%5==0 else Vector3.ONE*.001,shirt.darkened(.3))
    _crowd_part("bag",i,torso,Vector3(0,1.20,.22),Vector3(.29,.4,.16) if i%3==0 else Vector3.ONE*.001,shirt.darkened(.38))
    _crowd_part("zipper",i,torso,Vector3(0,1.15,-.172),Vector3(.022,.43,.018),shirt.darkened(.45))
    _crowd_part("hood",i,torso,Vector3(0,1.40,.12),Vector3(.19,.14,.14) if i%3==0 else Vector3.ONE*.001,shirt.darkened(.18))
    for side in 2:
        var sign_side = -1 if side == 0 else 1
        _crowd_part("ears",i*2+side,torso,Vector3(sign_side*.143,1.69,0),Vector3(.028,.05,.035),skin)
        _crowd_part("pockets",i*2+side,torso,Vector3(sign_side*.11,1.02,-.147),Vector3(.12,.09,.025),shirt.darkened(.14))
        _crowd_part("eyes",i*2+side,torso,Vector3(sign_side*.057,1.72,-.15),Vector3(.028,.025,.018),Color("282631"))
        # A stance foot moves backwards relative to the body, then lifts and
        # returns during swing. Analytic two-bone legs keep soles on the ground.
        var phase = fposmod(cycle/TAU+float(side)*.5,1.0)
        var foot_z: float
        var lift = 0.0
        if phase < .5:
            foot_z = lerpf(-.30,.30,phase*2.0)
        else:
            var t = (phase-.5)*2.0
            foot_z = lerpf(.30,-.30,smoothstep(0,1,t))
            lift = sin(t*PI)*.13
        var hip = Vector3(sign_side*.115,.82+bob,0)
        var ankle = Vector3(sign_side*.115,.10+lift*person.motion,foot_z*person.motion)
        var along = ankle-hip
        var distance = minf(along.length(),.799)
        var forward = Vector3.FORWARD-along.normalized()*Vector3.FORWARD.dot(along.normalized())
        var knee = (hip+ankle)*.5+forward.normalized()*sqrt(maxf(0,.4*.4-distance*distance*.25))
        _crowd_limb("legs",i*2+side,root_transform,hip,knee,.18,trousers)
        _crowd_part("knees",i*2+side,root_transform,knee,Vector3(.085,.09,.085),trousers)
        _crowd_limb("shins",i*2+side,root_transform,knee,ankle,.145,trousers)
        _crowd_part("shoes",i*2+side,root_transform,ankle+Vector3(0,-.045,-.055),Vector3(.18,.11,.30),Color("d5d1bc") if i%3==1 else Color("252b33"))
        var arm_angle = -gait*sign_side*.8
        var arm = torso * Transform3D(Basis(Vector3.RIGHT,arm_angle),Vector3(sign_side*.26*width,1.40,0))
        var forearm = arm * Transform3D(Basis(Vector3.RIGHT,-.18-absf(arm_angle)*.4),Vector3(0,-.27,0))
        _crowd_part("arms",i*2+side,arm,Vector3(0,-.135,0),Vector3(.15,.27,.17),shirt)
        _crowd_part("elbows",i*2+side,forearm,Vector3.ZERO,Vector3(.061,.063,.068),shirt)
        _crowd_part("forearms",i*2+side,forearm,Vector3(0,-.13,0),Vector3(.115,.26,.13),skin if i%2==0 else shirt)
        _crowd_part("hands",i*2+side,forearm,Vector3(0,-.29,0),Vector3(.07,.09,.07),skin)

func _crowd_limb(part: String, index: int, transform: Transform3D, a: Vector3, b: Vector3, width: float, color: Color):
    var direction = (b-a).normalized()
    var rotation_basis = Basis(Quaternion(Vector3.UP,direction))
    _crowd_part(part,index,transform*Transform3D(rotation_basis,(a+b)*.5),Vector3.ZERO,Vector3(width,a.distance_to(b),width),color)

func _crowd_part(part: String, index: int, root_transform: Transform3D, offset: Vector3, size: Vector3, color: Color):
    var mm: MultiMesh = crowd_meshes[part]
    mm.set_instance_transform(index,root_transform*Transform3D(Basis.IDENTITY.scaled(size),offset))
    mm.set_instance_color(index,color)

func _solid_box(pos: Vector3, size: Vector3):
    var body = StaticBody3D.new()
    body.position = pos
    var collision = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)
    solid_props += 1

func _bus_stop(block: Rect2, index: int):
    var p = Vector3(block.get_center().x,0,block.position.y+1.7)
    if not _clear(Vector2(p.x,p.z),3.5):
        return
    var metal = Color("334b57")
    for x in [-2.3,2.3]:
        _part("box",p+Vector3(x,1.45,0),Vector3(.12,2.9,.12),metal)
    _part("box",p+Vector3(0,2.95,0),Vector3(5,.22,2.0),Color("486f73"))
    _part("box",p+Vector3(0,1.4,.75),Vector3(4.8,2.4,.08),Color("617e85"))
    _part("box",p+Vector3(0,.55,.25),Vector3(3.6,.12,.55),Color("ba9670"))
    _part("box",p+Vector3(1.75,1.65,.68),Vector3(.8,1.15,.10),Color("e5c181"))
    _solid_box(p+Vector3(0,1.4,.75),Vector3(4.8,2.8,.12))
    var sign = Label3D.new()
    sign.text = "MDK3  //  " + str(20+index%9)
    sign.position = p+Vector3(0,2.55,-.15)
    sign.pixel_size = .01
    sign.font_size = 40
    sign.modulate = Color("fff0c6")
    sign.visibility_range_end = 100
    add_child(sign)
