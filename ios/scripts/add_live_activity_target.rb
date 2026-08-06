#!/usr/bin/env ruby
# frozen_string_literal: true

# เพิ่มเป้าหมาย widget extension ของ Live Activity เข้า Runner.xcodeproj
#
# ผลของสคริปต์นี้ถูก commit ไปกับ project.pbxproj แล้ว — ปกติจึงไม่ต้องรัน สิ่งที่มัน
# มีไว้เพื่อคือกรณีที่ไฟล์โปรเจ็กต์ถูกสร้างใหม่ (เช่นทำ `flutter create .` ทับ) แล้ว
# เป้าหมายหายไป รันซ้ำได้เสมอ ไม่สร้างซ้ำซ้อน
#
#   ruby ios/scripts/add_live_activity_target.rb
#
# ต้องมี xcodeproj (มากับ CocoaPods อยู่แล้ว): gem install xcodeproj

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../Runner.xcodeproj', __dir__)
TARGET_NAME = 'LiveActivityExtension'
GROUP_NAME = 'LiveActivity'
DEPLOYMENT_TARGET = '16.2'
# ไฟล์นี้ต้องอยู่ในทั้งสองเป้าหมาย — Runner ใช้ตอนเปิดการ์ด วิดเจ็ตใช้ตอนวาด
SHARED_SOURCES = ['TripActivityAttributes.swift'].freeze
EXTENSION_SOURCES = ['TripActivityAttributes.swift', 'TripActivityWidget.swift', 'LiveActivityBundle.swift'].freeze

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'ไม่พบเป้าหมาย Runner'

# สะพาน Flutter ↔ ActivityKit อยู่ในแอปหลัก ไม่ใช่ใน extension
runner_group = project.main_group.find_subpath('Runner', true)
unless runner.source_build_phase.files_references.any? { |f| f.path.to_s.end_with?('LiveActivityChannel.swift') }
  channel_file = runner_group.find_file_by_path('LiveActivityChannel.swift') ||
                 runner_group.new_file('LiveActivityChannel.swift')
  runner.add_file_references([channel_file])
  project.save
  puts 'เพิ่ม LiveActivityChannel.swift เข้าเป้าหมาย Runner แล้ว'
end

if project.targets.any? { |t| t.name == TARGET_NAME }
  puts "#{TARGET_NAME} มีอยู่แล้ว — ไม่ต้องทำอะไรต่อ"
  exit 0
end

base_bundle_id = runner.build_configurations
                       .map { |c| c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] }
                       .compact.first || 'com.luilaykhao.app'
team = runner.build_configurations.map { |c| c.build_settings['DEVELOPMENT_TEAM'] }.compact.first

extension_target = project.new_target(
  :app_extension,
  TARGET_NAME,
  :ios,
  DEPLOYMENT_TARGET,
  project.products_group,
  :swift
)

group = project.main_group.find_subpath(GROUP_NAME, true)
group.set_source_tree('SOURCE_ROOT')
group.set_path(GROUP_NAME)

EXTENSION_SOURCES.each do |name|
  file = group.find_file_by_path(name) || group.new_file(name)
  extension_target.add_file_references([file])
  # โครงสร้าง ContentState ต้องเป็นตัวเดียวกันทั้งสองฝั่ง จึงคอมไพล์เข้า Runner ด้วย
  runner.add_file_references([file]) if SHARED_SOURCES.include?(name)
end

group.new_file('Info.plist') unless group.find_file_by_path('Info.plist')

extension_target.build_configurations.each do |config|
  settings = config.build_settings
  # ไม่มีสองบรรทัดนี้ ผลลัพธ์จะกลายเป็นไฟล์ชื่อ ".appex" เปล่า ๆ แล้ว Xcode ตีกลับ
  # ว่า "Multiple commands produce" เพราะทุก configuration ผลิตชื่อเดียวกัน
  settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  settings['WRAPPER_EXTENSION'] = 'appex'
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{base_bundle_id}.LiveActivity"
  settings['INFOPLIST_FILE'] = "#{GROUP_NAME}/Info.plist"
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  settings['SWIFT_VERSION'] = '5.0'
  settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  settings['SKIP_INSTALL'] = 'YES'
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['DEVELOPMENT_TEAM'] = team if team
  settings['MARKETING_VERSION'] = '$(MARKETING_VERSION)'
  settings['CURRENT_PROJECT_VERSION'] = '$(CURRENT_PROJECT_VERSION)'
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = ''
  # extension ไม่ได้ลิงก์ Flutter/Pods เลย — มันวาด SwiftUI ล้วน ๆ จากข้อมูลที่ APNs
  # ส่งมา การลาก Flutter.framework เข้ามาจะทำให้ App Store ตีกลับเรื่องขนาดและสิทธิ์
  settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
end

# ฝัง extension ลงในแอปหลัก — ไม่มีขั้นนี้ก็บิลด์ผ่านแต่ไม่มีอะไรติดไปกับแอป
embed_phase = runner.build_phases.find do |phase|
  phase.respond_to?(:name) && phase.name == 'Embed App Extensions'
end
embed_phase ||= begin
  phase = runner.new_copy_files_build_phase('Embed App Extensions')
  phase.symbol_dst_subfolder_spec = :plug_ins
  phase
end
build_file = embed_phase.add_file_reference(extension_target.product_reference)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# ต้องอยู่ "ก่อน" Thin Binary ของ Flutter ไม่งั้น Xcode มองเป็น dependency cycle
# (Thin Binary ประกาศ Runner.app ทั้งก้อนเป็น output ส่วนขั้นนี้เขียนไฟล์ลงข้างใน)
# แล้วบิลด์ล้มด้วยข้อความ "Cycle inside Runner" ที่ไม่ได้บอกว่าเพราะอะไร
thin_index = runner.build_phases.find_index do |phase|
  phase.respond_to?(:name) && phase.name == 'Thin Binary'
end
if thin_index
  runner.build_phases.delete(embed_phase)
  runner.build_phases.insert(thin_index, embed_phase)
end

runner.add_dependency(extension_target)

project.save
puts "เพิ่ม #{TARGET_NAME} เรียบร้อย (bundle id: #{base_bundle_id}.LiveActivity)"
