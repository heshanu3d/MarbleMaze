import UIKit
import SceneKit

let CollisionCategoryBall = 1
let CollisionCategoryStone = 2
let CollisionCategoryPillar = 4
let CollisionCategoryCrate = 8
let CollisionCategoryPearl = 16

class GameViewController: UIViewController {
    var scnView:SCNView!
    var scnScene:SCNScene!
    var ballNode:SCNNode!
    var game = GameHelper.sharedInstance
    var motion = CoreMotionHelper()
    var motionForce = SCNVector3(x:0 , y:0, z:0)
    var cameraNode:SCNNode!
    var cameraFollowNode:SCNNode!
    var lightFollowNode:SCNNode!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 1
        setupScene()
        setupNodes()
        setupSounds()
        resetGame()
    }
    // 2
    func setupScene() {
        scnView = self.view as! SCNView
        scnView.delegate = self
//        scnView.allowsCameraControl = true
        scnView.showsStatistics = true
        
        scnScene = SCNScene(named: "art.scnassets/game.scn")
        scnView.scene = scnScene
        scnScene.physicsWorld.contactDelegate = self
        
    }
    func setupNodes() {
        ballNode = scnScene.rootNode.childNode(withName: "ball", recursively: true)!
        ballNode.physicsBody?.contactTestBitMask = CollisionCategoryPillar | CollisionCategoryCrate | CollisionCategoryPearl
        cameraNode = scnScene.rootNode.childNode(withName: "camera", recursively: true)!
        let constraint = SCNLookAtConstraint(target: ballNode)
        cameraNode.constraints = [constraint]
        constraint.isGimbalLockEnabled = true
        
        cameraFollowNode = scnScene.rootNode.childNode(withName: "follow_camera", recursively: true)!
        cameraNode.addChildNode(game.hudNode)
        lightFollowNode = scnScene.rootNode.childNode(withName: "follow_light", recursively: true)!
        
    }
    func setupSounds() {
        game.loadSound(name: "GameOver", fileNamed: "GameOver.wav")
        game.loadSound(name: "Powerup", fileNamed: "Powerup.wav")
        game.loadSound(name: "Reset", fileNamed: "Reset.wav")
        game.loadSound(name: "Bump", fileNamed: "Bump.wav")
    }
    
    func playGame() {
        game.state = GameStateType.playing
        cameraFollowNode.eulerAngles.y = 0
        cameraFollowNode.position = SCNVector3Zero
        replenishLife()
    }
    
    func resetGame() {
        game.state = GameStateType.tapToPlay
        game.playSound(node: ballNode, name: "Reset")
        ballNode.physicsBody!.velocity = SCNVector3Zero
        ballNode.position = SCNVector3(x:0, y:10, z:0)
        cameraFollowNode.position = ballNode.position
        lightFollowNode.position = ballNode.position
        scnView.isPlaying = true
        game.reset()
    }

    func testForGameOver() {
        if ballNode.presentation.position.y < -25 {
            game.state = GameStateType.gameOver
            game.playSound(node: ballNode, name: "GameOver")
            ballNode.runAction(SCNAction.waitForDurationThenRunBlock(duration: 5) { (node:SCNNode!) -> Void in
                self.resetGame()
            })
        }
    }
    
    func replenishLife() {
        let material = ballNode.geometry!.firstMaterial!
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0
        material.emission.intensity = 1.0
        SCNTransaction.commit()
        game.score += 1
        game.playSound(node: ballNode, name: "Powerup")
    }
    
    func diminishLife() {
        let material = ballNode.geometry!.firstMaterial!
        if material.emission.intensity > 0 {
            material.emission.intensity -= 0.001
        } else {
            resetGame()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        if game.state == GameStateType.tapToPlay {
            playGame() }
    }
    
    func updateMotionControl() {
        if game.state == GameStateType.playing {
            motion.getAccelerometerData(interval: 0.1) { (x,y,z) in
                self.motionForce = SCNVector3(x: Float(x) * 0.05, y:0, z: Float(y) * -0.05)
            }
            ballNode.physicsBody!.velocity += motionForce
        }
    }
    
    func updateCameraAndLights() {
        let lerpX = (ballNode.presentation.position.x - cameraFollowNode.position.x) * 0.01
        let lerpY = (ballNode.presentation.position.y - cameraFollowNode.position.y) * 0.01
        let lerpZ = (ballNode.presentation.position.z - cameraFollowNode.position.z) * 0.01
        cameraFollowNode.position.x += lerpX
        cameraFollowNode.position.y += lerpY
        cameraFollowNode.position.z += lerpZ

        lightFollowNode.position = cameraFollowNode.position

        if game.state == GameStateType.tapToPlay {
            cameraFollowNode.eulerAngles.y += 0.005
        }
  }

  func updateHUD() {
    switch game.state {
    case .playing:
      game.updateHUD()
    case .gameOver:
      game.updateHUD(s: "-GAME OVER-")
    case .tapToPlay:
      game.updateHUD(s: "-TAP TO PLAY-")
    }
  }
    
    override var shouldAutorotate : Bool { return false }
    override var prefersStatusBarHidden : Bool { return true }
}

extension GameViewController: SCNSceneRendererDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    updateHUD()
    updateMotionControl()
    updateCameraAndLights()
    
    if game.state == GameStateType.playing {
      testForGameOver()
      diminishLife()
    }
  }
}

extension GameViewController : SCNPhysicsContactDelegate {
    func physicsWorld(_ world: SCNPhysicsWorld,
                      didBegin contact: SCNPhysicsContact) {

        var contactNode:SCNNode!
        if contact.nodeA.name == "ball" {
            contactNode = contact.nodeB
        } else {
            contactNode = contact.nodeA
        }

        if contactNode.physicsBody?.categoryBitMask == CollisionCategoryPearl {
      replenishLife()
            contactNode.isHidden = true
            contactNode.runAction(
                SCNAction.waitForDurationThenRunBlock( duration: 30) {
                    (node:SCNNode!) -> Void in
                    node.isHidden = false })
        }

        if contactNode.physicsBody?.categoryBitMask == CollisionCategoryPillar
            || contactNode.physicsBody?.categoryBitMask == CollisionCategoryCrate {
            game.playSound(node: ballNode, name: "Bump")
        } }
}
