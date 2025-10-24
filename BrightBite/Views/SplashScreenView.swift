//
//  SplashScreenView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 11/1/25.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var glowIntensity: Double = 0
    @State private var leftCurtainOffset: CGFloat = 0
    @State private var rightCurtainOffset: CGFloat = 0
    @Binding var isActive: Bool

    var body: some View {
        ZStack {
            
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.15),
                    Color.cyan.opacity(0.1),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            
            VStack(spacing: 20) {
                
                ZStack {
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.blue.opacity(glowIntensity * 0.35),
                                    Color.cyan.opacity(glowIntensity * 0.25),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(scale * 1.2)
                        .opacity(opacity)

                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.blue.opacity(glowIntensity * 0.4),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 30,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(scale * 1.1)
                        .opacity(opacity)

                    
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.blue.opacity(0.5),
                                            Color.cyan.opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: .blue.opacity(glowIntensity * 0.5), radius: 20)
                        .shadow(color: .cyan.opacity(glowIntensity * 0.3), radius: 40)
                        .scaleEffect(scale)
                        .opacity(opacity)

                    
                    Image(systemName: "mouth.fill")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(scale)
                        .opacity(opacity)
                }

                
                Text("BrightBite")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(opacity)
                    .scaleEffect(scale)

                
                Text("Bite better, shine brighter")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .opacity(opacity * 0.8)
            }
            .opacity(opacity)

            
            GeometryReader { geometry in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.1),
                                Color.cyan.opacity(0.05),
                                Color.white
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: geometry.size.width / 2)
                    .offset(x: leftCurtainOffset)
                    .ignoresSafeArea()
            }

            
            GeometryReader { geometry in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.1),
                                Color.cyan.opacity(0.05),
                                Color.white
                            ],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .frame(width: geometry.size.width / 2)
                    .offset(x: geometry.size.width / 2 + rightCurtainOffset)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        
        withAnimation(.easeOut(duration: 0.8)) {
            scale = 1.0
            opacity = 1.0
        }

        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowIntensity = 1.0
        }

        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                
                leftCurtainOffset = -UIScreen.main.bounds.width / 2
                
                rightCurtainOffset = UIScreen.main.bounds.width / 2
                
                opacity = 0
                glowIntensity = 0
            }

            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isActive = false
            }
        }
    }
}

#Preview {
    SplashScreenView(isActive: .constant(true))
}
