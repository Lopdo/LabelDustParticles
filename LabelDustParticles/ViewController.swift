//
//  ViewController.swift
//  LabelDustParticles
//
//  Created by Lope on 09/02/2018.
//  Copyright © 2018 Lost Bytes. All rights reserved.
//

import UIKit
import SpriteKit
import CoreGraphics
import GameplayKit

class ViewController: UIViewController {

	@IBOutlet var skView: SKView!
	@IBOutlet var imgView: UIImageView!

	var spawnPoints: [CGPoint] = []

	var scene: MyScene!

	override func viewDidLoad() {
		super.viewDidLoad()

		updateImage()


		scene = MyScene(size: CGSize(width: skView.bounds.width, height: skView.bounds.height))
		scene.scale = UIScreen.main.scale
		scene.scaleMode = .resizeFill
		scene.backgroundColor = UIColor.clear
		scene.spawnPoints = spawnPoints
		skView.presentScene(scene)
		skView.allowsTransparency = true
		skView.backgroundColor = UIColor.clear
		//skView.showsFPS = true
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		let scale = UIScreen.main.scale

		scene.updateOffset(x: (imgView.frame.origin.x - skView.frame.origin.x) * scale,
						   y: (imgView.frame.origin.y - skView.frame.origin.y) * scale)
	}

	func updateImage() {

		let label = UILabel()
		label.font = UIFont.systemFont(ofSize: 50)
		label.textColor = UIColor(white: 0.15, alpha: 1)
		label.text = "012 345 6789"
		label.backgroundColor = UIColor.white // clear BG doesn't work, introduces artefacts, replace with desired BG color
		label.isOpaque = false
		label.sizeToFit()

		let scale = UIScreen.main.scale
		let width = Int(label.frame.width * scale)
		let height = Int(label.frame.height * scale)

		let bitsPerComponent = 8

		let bytesPerPixel = 4
		let bytesPerRow = width * bytesPerPixel
		let colorSpace = CGColorSpaceCreateDeviceRGB()

		let imageData = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * bytesPerPixel)

		let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
		let imageContext = CGContext(data: imageData, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo, releaseCallback: nil, releaseInfo: nil)

		imageContext!.translateBy(x: 0.0, y: CGFloat(height))
		imageContext!.scaleBy(x: scale, y: -scale)

		label.layer.render(in: imageContext!)

		spawnPoints.reserveCapacity(width * 24 * Int(scale*scale) / 2)

		for y in 0..<height {
			let minHeight = 22 * Int(scale)
			let interpHeight = 24 * Int(scale)
			var transparencyOdds: UInt32 = 0
			if (height - y) < minHeight {
				transparencyOdds = 0
			} else if (height - y) > minHeight + interpHeight {
				transparencyOdds = 100
			} else {
				transparencyOdds = UInt32((Double((height - y) - minHeight) / Double(interpHeight)) * 100)
			}

			for x in 0..<width {
				let index = ((Int(bytesPerRow) * Int(y)) + Int(x) * bytesPerPixel)
				let transparent = arc4random() % 100 < UInt32(transparencyOdds)
				if transparent {
					if imageData[index + 0] != 255 {
						spawnPoints.append(CGPoint(x: CGFloat(x), y: CGFloat(height - y)))
						imageData[index + 3] = 0
					}
				}
			}
		}

		let cgImage = imageContext?.makeImage()
		imgView.image = UIImage(cgImage: cgImage!, scale: scale, orientation: .up)
		imgView.sizeToFit()
	}

}

class MyScene: SKScene {

	var spawnPoints: [CGPoint] = []

	var canvasNode: SKNode!
	var canvasSprite: SKSpriteNode!

	var lastTime: TimeInterval = 0

	var offsetX: CGFloat = 0
	var offsetY: CGFloat = 0

	var scale: CGFloat!

	var particles: [ParticleNode] = []
	var maxParticleCount: Int = 100

	var particleCounter: Int = 0

	override func didChangeSize(_ oldSize: CGSize) {
		updateLayout()
	}

	func updateOffset(x offsetX: CGFloat, y offsetY: CGFloat) {
		self.offsetX = offsetX
		self.offsetY = offsetY

		updateLayout()
	}

	func updateLayout() {
		guard spawnPoints.count > 0 else {
			return
		}

		print(frame)

		removeAllChildren()
		particles.removeAll()

		canvasNode = SKNode()

		maxParticleCount = Int(size.width * scale * 2)

		spawnParticles(-1)

		let canvasTexture = view!.texture(from: canvasNode, crop: CGRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale))
		canvasSprite = SKSpriteNode(texture: canvasTexture, size: canvasTexture!.size())

		canvasSprite.anchorPoint = CGPoint(x: 0, y: 0)
		canvasSprite.setScale(1.0 / scale)
		addChild(canvasSprite)
	}

	func spawnParticles(_ count: Int) {

		var spawnCount = count
		if spawnCount == -1 {
			spawnCount = maxParticleCount / 100
		}

		for _ in 0..<spawnCount {

			if particles.count > maxParticleCount {
				break
			}

			let spawn = spawnPoints[Int(arc4random()) % spawnPoints.count]
			let particle = ParticleNode(pos: CGPoint(x: spawn.x + offsetX, y: spawn.y), scale: scale, id: particleCounter)
			particleCounter += 1
			particles.append(particle)
			self.canvasNode.addChild(particle)
		}
	}

	func updateParticles(_ timeDelta: CGFloat) {
		for (index, particle) in particles.enumerated().reversed() {
			particle.move(timeDelta)
			if particle.lifetime < 0 {
				particle.removeFromParent()
				particles.remove(at: index)
			}
		}
	}

	override func update(_ currentTime: TimeInterval) {

		var delta = CGFloat(currentTime - lastTime) / 1
		if delta > 0.1 {
			delta = 0.1
		}
		lastTime = currentTime

		updateParticles(delta)

		spawnParticles(-1)

		let canvasTexture = self.view!.texture(from: self.canvasNode, crop: CGRect(x: 0, y: 0, width: self.size.width * scale, height: self.size.height * scale))
		canvasSprite.texture = canvasTexture
	}

}

class ParticleNode: SKSpriteNode {

	var id: Int = -1

	let minimumSpeed: CGFloat = 8.0
	let deceleration: CGFloat = 6.0

	var angle: CGFloat = 0.0
	var currentSpeed: CGFloat = 0.0

	var speedX: CGFloat = 0
	var speedY: CGFloat = 0

	var lifetime: CGFloat = 0

	var timeToChange: CGFloat = 0.0

	//var wind: Wind!

	init(pos: CGPoint, scale: CGFloat, id: Int) {
		super.init(texture: nil, color: UIColor(white: randomizeValue(0.15, spread: 0.05), alpha: 1), size: CGSize(width: scale * 0.75, height: scale * 0.75))

		self.id = id

		let lifetimeInitial: CGFloat = 4
		let lifetimeRange: CGFloat = 1.5

		angle = randomizeValue(0, spread: 4)
		currentSpeed = minimumSpeed
		timeToChange = randomizeValue(1.5, spread: 0.5)

		speedX = sin(angle) * currentSpeed
		speedY = cos(angle) * currentSpeed

		lifetime = randomizeValue(lifetimeInitial, spread: lifetimeRange)

		position = pos
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func move(_ timeDelta: CGFloat) {

		currentSpeed -= timeDelta * deceleration

		if currentSpeed < minimumSpeed {
			currentSpeed = minimumSpeed
		}

		speedX = sin(angle) * currentSpeed
		speedY = cos(angle) * currentSpeed

		position.x = position.x + speedX * timeDelta
		position.y = position.y + speedY * timeDelta

		lifetime -= timeDelta

		if lifetime < 2 {
			alpha = lifetime / 2
		}

		timeToChange -= timeDelta
		if timeToChange < 0 {
			timeToChange = randomizeValue(1, spread: 0.5)

			angle = nextGaussian() / 2

			currentSpeed = randomizeValue(20, spread: 50)
		}
	}
}

func randomizeValue(_ value: CGFloat, spread: CGFloat) -> CGFloat {
	return value + spread / 2 - CGFloat(arc4random()) / CGFloat(UINT32_MAX) * spread
}

private var nextNextGaussian: CGFloat? = {
	srand48(Int(arc4random())) //initialize drand48 buffer at most once
	return nil
}()

func nextGaussian() -> CGFloat {
	if let gaussian = nextNextGaussian {
		nextNextGaussian = nil
		return gaussian
	} else {
		var v1, v2, s: CGFloat

		repeat {
			v1 = 2 * CGFloat(drand48()) - 1
			v2 = 2 * CGFloat(drand48()) - 1
			s = v1 * v1 + v2 * v2
		} while s >= 1 || s == 0

		let multiplier = sqrt(-2 * log(s)/s)
		nextNextGaussian = v2 * multiplier
		return v1 * multiplier
	}
}
