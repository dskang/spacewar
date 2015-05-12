//
//  GameScene.swift
//  Spacewar
//
//  Created by Dan Kang on 4/20/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import SpriteKit
import CoreMotion

class GameScene: SKScene, SKPhysicsContactDelegate {

    let shipCategory: UInt32 = 0x1 << 0
    let missileCategory: UInt32 = 0x1 << 1
    let starCategory: UInt32 = 0x1 << 2

    let kShipName = "ship"
    let kEnemyName = "enemy"
    let kMissileName = "missile"
    let motionManager = CMMotionManager()

    var tapQueue: Array<Int> = []

    override func didMoveToView(view: SKView) {
        /* Setup your scene here */
        motionManager.startAccelerometerUpdates()
        scaleMode = SKSceneScaleMode.AspectFit
        physicsBody = SKPhysicsBody(edgeLoopFromRect: frame)
        physicsWorld.gravity = CGVectorMake(0, 0)
        physicsWorld.contactDelegate = self
        backgroundColor = SKColor.blackColor()

        let ship = makeShip(kShipName)
        ship.position = CGPoint(x: size.width * 0.7, y: size.height * 0.3)
        addChild(ship)

        let enemy = makeShip(kEnemyName)
        enemy.position = CGPoint(x: size.width * 0.3, y: size.height * 0.7)
        enemy.zRotation = CGFloat(M_PI)
        if let enemy = enemy as? SKSpriteNode {
            enemy.color = SKColor.redColor()
            enemy.colorBlendFactor = 0.5
        }
        addChild(enemy)

        let star = makeStar()
        addChild(star)

        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let gravityField = SKFieldNode.radialGravityField()
        gravityField.position = center
        gravityField.strength = 0.5
        addChild(gravityField)
    }

    func didBeginContact(contact: SKPhysicsContact) {
        var firstBody: SKPhysicsBody, secondBody: SKPhysicsBody
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        if firstBody.categoryBitMask & shipCategory != 0 {
            println("ship")
        } else if firstBody.categoryBitMask & missileCategory != 0 {
            println("missile")
        } else {
            println("star")
        }

        if secondBody.categoryBitMask & shipCategory != 0 {
            println("ship")
        } else if secondBody.categoryBitMask & missileCategory != 0 {
            println("missile")
        } else {
            println("star")
        }
    }
    
    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
        /* Called when a touch begins */

        if let touch = touches.first as? UITouch {
            let location = touch.locationInView(view)
            if location.x > view?.center.x {
                // Fire missile
                tapQueue.append(1)
            } else {
                // Propel ship
                if let ship = childNodeWithName(kShipName) {
                    let rotation = Float(ship.zRotation) + Float(M_PI_2)
                    let thrust: CGFloat = 500.0
                    let xv = thrust * CGFloat(cosf(rotation))
                    let yv = thrust * CGFloat(sinf(rotation))
                    let thrustVector = CGVectorMake(xv, yv)
                    ship.physicsBody?.applyForce(thrustVector)
                }
            }
        }
    }
   
    override func update(currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
        processUserMotionForUpdate(currentTime)
        processUserTapsForUpdate(currentTime)
    }

    func makeStar() -> SKNode {
        let star = SKSpriteNode(color: SKColor.whiteColor(), size: CGSizeMake(5, 5))
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        star.position = center

        star.physicsBody = SKPhysicsBody(circleOfRadius: 1)
        star.physicsBody!.dynamic = false
        star.physicsBody!.categoryBitMask = starCategory

        return star
    }

    func makeShip(name: String) -> SKNode {
        let ship = SKSpriteNode(imageNamed:"Spaceship")
        ship.name = name
        ship.xScale = 0.1
        ship.yScale = 0.1

        ship.physicsBody = SKPhysicsBody(rectangleOfSize: ship.frame.size)
        ship.physicsBody!.mass = 1.0
        ship.physicsBody!.categoryBitMask = shipCategory
        ship.physicsBody!.contactTestBitMask = shipCategory | missileCategory | starCategory
        ship.physicsBody!.collisionBitMask = 0x0

        return ship
    }

    func makeMissile(ship: SKNode) -> SKNode {
        let missile = SKSpriteNode(color: SKColor.grayColor(), size: CGSizeMake(4, 8))
        missile.name = kMissileName
        missile.zRotation = ship.zRotation

        missile.physicsBody = SKPhysicsBody(rectangleOfSize: missile.frame.size)
        missile.physicsBody!.velocity = ship.physicsBody!.velocity
        missile.physicsBody!.mass = 0.1
        missile.physicsBody!.categoryBitMask = missileCategory

        return missile
    }

    func fireMissile(missile: SKNode, destination: CGPoint, duration: CFTimeInterval) {
        let missileAction = SKAction.sequence([SKAction.moveTo(destination, duration: duration), SKAction.waitForDuration(3.0/60.0), SKAction.removeFromParent()])
        missile.runAction(missileAction)
        addChild(missile)
    }

    func fireShipMissiles() {
        if let ship = childNodeWithName(kShipName) {
            let missile = makeMissile(ship)

            let shipDirection = Float(ship.zRotation) + Float(M_PI_2)
            let padding = ship.frame.size.height - missile.frame.size.height / 2
            let missileX = ship.position.x + CGFloat(cosf(shipDirection)) * padding
            let missileY = ship.position.y + CGFloat(sinf(shipDirection)) * padding
            missile.position = CGPointMake(missileX, missileY)

            let destX = ship.position.x + CGFloat(cosf(shipDirection)) * 500
            let destY = ship.position.y + CGFloat(sinf(shipDirection)) * 500
            let missileDestination = CGPointMake(destX, destY)
            fireMissile(missile, destination: missileDestination, duration: 1.0)
        }
    }

    func processUserTapsForUpdate(currentTime: CFTimeInterval) {
        for tap in tapQueue {
            fireShipMissiles()
            tapQueue.removeAtIndex(0)
        }
    }

    func processUserMotionForUpdate(currentTime: CFTimeInterval) {
        let ship = childNodeWithName(kShipName) as! SKSpriteNode
        if let data = motionManager.accelerometerData {
            if fabs(data.acceleration.y) > 0.1 {
                // Rotate ship
                let rotate = SKAction.rotateByAngle(CGFloat(data.acceleration.y * M_PI_2 * -0.1), duration: 0.1)
                ship.runAction(rotate)
            }
        }
    }
}
